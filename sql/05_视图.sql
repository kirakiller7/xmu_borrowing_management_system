USE xmu_borrowing_system;

CREATE VIEW v_station_available_items AS
SELECT s.station_id, s.station_name, t.type_name, COUNT(i.item_id) AS available_count
FROM service_station s
JOIN item_asset i ON s.station_id = i.station_id
JOIN item_type t ON i.type_id = t.type_id
WHERE i.status = '可用'
GROUP BY s.station_id, s.station_name, t.type_name;

CREATE VIEW v_student_unreturned AS
SELECT br.borrow_id, stu.student_id, stu.student_name, it.type_name, ia.asset_code, br.borrow_time, br.due_time, br.borrow_status
FROM borrow_record br
JOIN student stu ON br.student_id = stu.student_id
JOIN item_asset ia ON br.item_id = ia.item_id
JOIN item_type it ON ia.type_id = it.type_id
WHERE br.borrow_status = '借出中';

CREATE VIEW v_overdue_records AS
SELECT br.borrow_id, stu.student_name, it.type_name, ia.asset_code, br.borrow_time, br.due_time, TIMESTAMPDIFF(HOUR, br.due_time, NOW()) AS overdue_hours
FROM borrow_record br
JOIN student stu ON br.student_id = stu.student_id
JOIN item_asset ia ON br.item_id = ia.item_id
JOIN item_type it ON ia.type_id = it.type_id
WHERE br.borrow_status = '借出中' AND br.due_time < NOW();

CREATE VIEW v_maintenance_summary AS
SELECT it.type_name, mr.problem_type, COUNT(*) AS problem_count
FROM maintenance_record mr
JOIN item_asset ia ON mr.item_id = ia.item_id
JOIN item_type it ON ia.type_id = it.type_id
GROUP BY it.type_name, mr.problem_type;