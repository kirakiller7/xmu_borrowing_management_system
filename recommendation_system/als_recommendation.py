import csv
import math
from typing import Dict, List, Tuple, Any

import numpy as np
import pymysql


DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "这里要输入你的密码",
    "database": "xmu_borrowing_system",
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.DictCursor,
}


OUTPUT_CSV = "recommendation_result.csv"


def get_connection():
    return pymysql.connect(**DB_CONFIG)


def fetch_students() -> List[Dict[str, Any]]:
    sql = """
    SELECT student_id, student_name, credit_score
    FROM student
    ORDER BY student_id;
    """
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            return cursor.fetchall()


def fetch_item_types() -> List[Dict[str, Any]]:
    sql = """
    SELECT type_id, type_name
    FROM item_type
    ORDER BY type_id;
    """
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            return cursor.fetchall()


def fetch_interactions() -> List[Dict[str, Any]]:
    """
    读取学生历史借用行为。
    一条借还记录代表一次隐式反馈。
    """
    sql = """
    SELECT
        br.student_id,
        ia.type_id,
        COUNT(*) AS borrow_count
    FROM borrow_record br
    JOIN item_asset ia ON br.item_id = ia.item_id
    GROUP BY br.student_id, ia.type_id;
    """
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            return cursor.fetchall()


def fetch_type_popularity() -> Dict[int, int]:
    """
    统计各物资类型历史借用次数，作为流行度补充。
    """
    sql = """
    SELECT
        ia.type_id,
        COUNT(*) AS borrow_count
    FROM borrow_record br
    JOIN item_asset ia ON br.item_id = ia.item_id
    GROUP BY ia.type_id;
    """
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            rows = cursor.fetchall()

    return {row["type_id"]: int(row["borrow_count"]) for row in rows}


def fetch_available_stations() -> Dict[int, List[Dict[str, Any]]]:
    """
    查询每种物资类型在哪些服务点还有可用库存。
    """
    sql = """
    SELECT
        ia.type_id,
        it.type_name,
        s.station_id,
        s.station_name,
        s.campus_area,
        COUNT(*) AS available_count
    FROM item_asset ia
    JOIN item_type it ON ia.type_id = it.type_id
    JOIN service_station s ON ia.station_id = s.station_id
    WHERE ia.status = '可用'
    GROUP BY
        ia.type_id,
        it.type_name,
        s.station_id,
        s.station_name,
        s.campus_area
    ORDER BY ia.type_id, available_count DESC;
    """
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            rows = cursor.fetchall()

    result: Dict[int, List[Dict[str, Any]]] = {}
    for row in rows:
        result.setdefault(row["type_id"], []).append(row)

    return result


def build_interaction_matrix(
    students: List[Dict[str, Any]],
    item_types: List[Dict[str, Any]],
    interactions: List[Dict[str, Any]]
) -> Tuple[np.ndarray, Dict[str, int], Dict[int, int]]:
    """
    构造学生 × 物资类型矩阵 R。
    R[u, i] = 学生 u 借用物资类型 i 的次数。
    """
    student_index = {
        student["student_id"]: idx
        for idx, student in enumerate(students)
    }

    type_index = {
        item["type_id"]: idx
        for idx, item in enumerate(item_types)
    }

    R = np.zeros((len(students), len(item_types)), dtype=float)

    for row in interactions:
        sid = row["student_id"]
        tid = row["type_id"]
        cnt = row["borrow_count"]

        if sid in student_index and tid in type_index:
            R[student_index[sid], type_index[tid]] = float(cnt)

    return R, student_index, type_index


def implicit_als(
    R: np.ndarray,
    factors: int = 4,
    iterations: int = 20,
    alpha: float = 20.0,
    reg: float = 0.1,
    seed: int = 42
) -> Tuple[np.ndarray, np.ndarray]:
    """
    隐式反馈 ALS 矩阵分解。

    R: 学生 × 物资类型借用次数矩阵。
    P: 偏好矩阵，借过则为 1，没借过为 0。
    C: 置信度矩阵，借用次数越多，置信度越高。

    目标：
    学习学生隐向量 X 和物资隐向量 Y，
    使 X @ Y.T 能预测学生对物资类型的潜在兴趣。
    """
    num_users, num_items = R.shape

    if num_users == 0 or num_items == 0:
        raise ValueError("交互矩阵为空，无法训练 ALS 模型。")

    factors = max(1, min(factors, num_users, num_items))

    rng = np.random.default_rng(seed)
    X = rng.normal(0, 0.1, size=(num_users, factors))
    Y = rng.normal(0, 0.1, size=(num_items, factors))

    P = (R > 0).astype(float)
    C = 1.0 + alpha * R

    I = np.eye(factors)

    for _ in range(iterations):
        # 固定物资向量 Y，更新学生向量 X
        for u in range(num_users):
            Cu = np.diag(C[u])
            Pu = P[u]

            A = Y.T @ Cu @ Y + reg * I
            b = Y.T @ Cu @ Pu

            X[u] = np.linalg.solve(A, b)

        # 固定学生向量 X，更新物资向量 Y
        for i in range(num_items):
            Ci = np.diag(C[:, i])
            Pi = P[:, i]

            A = X.T @ Ci @ X + reg * I
            b = X.T @ Ci @ Pi

            Y[i] = np.linalg.solve(A, b)

    return X, Y


def normalize_scores(values: np.ndarray) -> np.ndarray:
    """
    把分数归一化到 0-1。
    """
    if len(values) == 0:
        return values

    min_v = np.min(values)
    max_v = np.max(values)

    if abs(max_v - min_v) < 1e-9:
        return np.ones_like(values) * 0.5

    return (values - min_v) / (max_v - min_v)


def choose_best_station(
    type_id: int,
    available_stations: Dict[int, List[Dict[str, Any]]]
) -> Tuple[str, int]:
    """
    为推荐物资类型选择可用数量最多的服务点。
    """
    stations = available_stations.get(type_id, [])

    if not stations:
        return "暂无可用服务点", 0

    best = max(stations, key=lambda x: x["available_count"])
    return best["station_name"], int(best["available_count"])


def generate_recommendations(
    students: List[Dict[str, Any]],
    item_types: List[Dict[str, Any]],
    R: np.ndarray,
    X: np.ndarray,
    Y: np.ndarray,
    top_k: int = 3
) -> List[Dict[str, Any]]:
    """
    生成推荐结果。
    最终分数 = ALS 潜在偏好分 + 历史流行度分 + 当前库存可用分。
    """
    type_popularity = fetch_type_popularity()
    available_stations = fetch_available_stations()

    type_id_list = [item["type_id"] for item in item_types]
    type_name_map = {
        item["type_id"]: item["type_name"]
        for item in item_types
    }

    popularity_vec = np.array([
        type_popularity.get(tid, 0)
        for tid in type_id_list
    ], dtype=float)

    availability_vec = np.array([
        sum(station["available_count"] for station in available_stations.get(tid, []))
        for tid in type_id_list
    ], dtype=float)

    popularity_norm = normalize_scores(popularity_vec)
    availability_norm = normalize_scores(availability_vec)

    latent_scores = X @ Y.T

    results: List[Dict[str, Any]] = []

    for u, student in enumerate(students):
        latent_norm = normalize_scores(latent_scores[u])

        # 混合推荐分数：模型预测 + 物资流行度 + 当前可用库存
        final_scores = (
            0.75 * latent_norm
            + 0.15 * popularity_norm
            + 0.10 * availability_norm
        )

        # 为了避免推荐完全没有库存的物资，库存为 0 时轻微降权
        for i, tid in enumerate(type_id_list):
            if availability_vec[i] <= 0:
                final_scores[i] -= 0.3

        ranked_indices = np.argsort(final_scores)[::-1][:top_k]

        for rank, i in enumerate(ranked_indices, start=1):
            type_id = type_id_list[i]
            type_name = type_name_map[type_id]
            best_station, station_available = choose_best_station(type_id, available_stations)

            history_count = int(R[u, i])

            if history_count > 0:
                reason = f"该学生历史借用过 {history_count} 次，模型判断存在持续需求"
            else:
                reason = "根据相似学生借用行为和物资整体热度预测存在潜在需求"

            results.append({
                "student_id": student["student_id"],
                "student_name": student["student_name"],
                "rank": rank,
                "recommended_type": type_name,
                "score": round(float(final_scores[i]), 4),
                "best_station": best_station,
                "station_available": station_available,
                "reason": reason,
            })

    return results


def fallback_recommendations(
    students: List[Dict[str, Any]],
    item_types: List[Dict[str, Any]],
    top_k: int = 3
) -> List[Dict[str, Any]]:
    """
    当历史借还数据太少时，使用流行度 + 当前库存作为备用推荐。
    """
    type_popularity = fetch_type_popularity()
    available_stations = fetch_available_stations()

    candidates = []
    for item in item_types:
        tid = item["type_id"]
        popularity = type_popularity.get(tid, 0)
        availability = sum(st["available_count"] for st in available_stations.get(tid, []))
        score = popularity * 0.7 + availability * 0.3
        candidates.append((tid, item["type_name"], score))

    candidates.sort(key=lambda x: x[2], reverse=True)

    results = []

    for student in students:
        for rank, (tid, type_name, score) in enumerate(candidates[:top_k], start=1):
            best_station, station_available = choose_best_station(tid, available_stations)

            results.append({
                "student_id": student["student_id"],
                "student_name": student["student_name"],
                "rank": rank,
                "recommended_type": type_name,
                "score": round(float(score), 4),
                "best_station": best_station,
                "station_available": station_available,
                "reason": "历史交互数据较少，采用物资流行度和当前库存进行推荐",
            })

    return results


def print_table(rows: List[Dict[str, Any]]) -> None:
    if not rows:
        print("暂无推荐结果。")
        return

    columns = [
        "student_id",
        "student_name",
        "rank",
        "recommended_type",
        "score",
        "best_station",
        "station_available",
        "reason",
    ]

    widths = {}
    for col in columns:
        widths[col] = max(
            len(str(col)),
            max(len(str(row.get(col, ""))) for row in rows)
        )

    header = " | ".join(str(col).ljust(widths[col]) for col in columns)
    line = "-+-".join("-" * widths[col] for col in columns)

    print(header)
    print(line)

    for row in rows:
        print(" | ".join(str(row.get(col, "")).ljust(widths[col]) for col in columns))


def save_to_csv(rows: List[Dict[str, Any]], file_path: str) -> None:
    if not rows:
        return

    columns = [
        "student_id",
        "student_name",
        "rank",
        "recommended_type",
        "score",
        "best_station",
        "station_available",
        "reason",
    ]

    with open(file_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


def main():
    print("=" * 90)
    print("厦大共享雨具与便民物资借还管理系统")
    print("AI 拓展模块：基于隐式反馈矩阵分解 ALS 的个性化物资推荐")
    print("=" * 90)

    students = fetch_students()
    item_types = fetch_item_types()
    interactions = fetch_interactions()

    print(f"学生数量：{len(students)}")
    print(f"物资类型数量：{len(item_types)}")
    print(f"历史交互记录数量：{len(interactions)}")

    R, _, _ = build_interaction_matrix(students, item_types, interactions)

    if R.sum() == 0 or R.shape[0] < 2 or R.shape[1] < 2:
        print("\n历史借还数据较少，启用备用推荐策略。")
        recommendations = fallback_recommendations(students, item_types, top_k=3)
    else:
        print("\n开始训练 ALS 矩阵分解模型...")
        X, Y = implicit_als(
            R,
            factors=4,
            iterations=20,
            alpha=20.0,
            reg=0.1
        )
        print("模型训练完成，正在生成推荐结果...")
        recommendations = generate_recommendations(
            students,
            item_types,
            R,
            X,
            Y,
            top_k=3
        )

    print("\n推荐结果：")
    print_table(recommendations)

    save_to_csv(recommendations, OUTPUT_CSV)
    print(f"\n推荐结果已保存到：{OUTPUT_CSV}")

    print("\n算法说明：")
    print("1. 本模块使用借还记录构造学生—物资类型隐式反馈矩阵。")
    print("2. ALS 矩阵分解学习学生偏好向量和物资类型向量。")
    print("3. 最终推荐分数综合模型预测、历史流行度和当前库存。")
    print("4. 模块只读取数据库，不修改原有表结构和业务数据。")


if __name__ == "__main__":
    main()