USE xmu_borrowing_system;

-- T01：查询各服务点可用物资
SELECT * FROM v_station_available_items;

-- T02：学生正常借用物资
CALL borrow_item('15220220241001', 1, 1);

SET @borrow_normal = (
    SELECT MAX(borrow_id)
    FROM borrow_record
    WHERE student_id = '15220220241001'
);

SELECT 'T02 借用后的借还记录' AS test_name;
SELECT *
FROM borrow_record
WHERE borrow_id = @borrow_normal;

SELECT 'T02 借用后的物资状态' AS test_name;
SELECT ia.item_id, ia.asset_code, ia.status, ia.station_id
FROM item_asset ia
JOIN borrow_record br ON ia.item_id = br.item_id
WHERE br.borrow_id = @borrow_normal;

-- T03：借用无可用库存的物资
-- 预期结果：报错“该服务点暂无可用物资”
CALL borrow_item('15220220241001', 3, 2);

-- T04：查询学生未归还记录
SELECT * FROM v_student_unreturned;

-- T05：学生正常归还物资
CALL return_item(@borrow_normal, 1);

SELECT 'T05 归还后的借还记录' AS test_name;
SELECT *
FROM borrow_record
WHERE borrow_id = @borrow_normal;

SELECT 'T05 归还后的物资状态' AS test_name;
SELECT ia.item_id, ia.asset_code, ia.status, ia.station_id
FROM item_asset ia
JOIN borrow_record br ON ia.item_id = br.item_id
WHERE br.borrow_id = @borrow_normal;

-- T06：构造逾期归还，验证触发器自动扣分
CALL borrow_item('15220220241002', 1, 2);

SET @borrow_overdue = (
    SELECT MAX(borrow_id)
    FROM borrow_record
    WHERE student_id = '15220220241002'
);

UPDATE borrow_record
SET borrow_time = DATE_SUB(NOW(), INTERVAL 30 HOUR),
    due_time = DATE_SUB(NOW(), INTERVAL 6 HOUR)
WHERE borrow_id = @borrow_overdue;

-- 现在归还，会触发逾期扣分触发器
CALL return_item(@borrow_overdue, 1);

-- 查看逾期归还后的借还记录
SELECT *
FROM borrow_record
WHERE borrow_id = @borrow_overdue;

-- 查看自动生成的信用扣分记录
SELECT credit_id, student_id, change_value, reason, related_borrow_id, created_time
FROM credit_record
WHERE related_borrow_id = @borrow_overdue;

-- 查看学生信用分变化
SELECT student_id, student_name, credit_score
FROM student
WHERE student_id = '15220220241002';

-- T07：查询当前逾期未归还记录
SELECT * FROM v_overdue_records;

-- T08：查询维修统计
SELECT * FROM v_maintenance_summary;

-- T09：维修流程简单验证
SELECT 'T09 维修前物资状态' AS test_name;
SELECT item_id, asset_code, status
FROM item_asset
WHERE item_id = 8;

UPDATE maintenance_record
SET maintenance_status = '已完成',
    end_time = NOW()
WHERE item_id = 8;

UPDATE item_asset
SET status = '可用'
WHERE item_id = 8;

SELECT 'T09 维修完成后的维修记录' AS test_name;
SELECT *
FROM maintenance_record
WHERE item_id = 8;

SELECT 'T09 维修完成后的物资状态' AS test_name;
SELECT item_id, asset_code, status
FROM item_asset
WHERE item_id = 8;