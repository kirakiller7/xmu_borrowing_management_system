-- Active: 1776932878355@@127.0.0.1@3306@xmu_borrowing_system
use xmu_borrowing_system;
INSERT INTO college (college_name, phone) VALUES
('信息学院', '0592-1234567'),
('经济学院', '0592-2345678'),
('管理学院', '0592-3456789');

INSERT INTO student (student_id, student_name, gender, phone, credit_score, college_id) VALUES
('15220220241001', '张三', '男', '15912340001', 100, 1),
('15220220241002', '李四', '女', '15912340002', 100, 2),
('15220220241003', '王五', '男', '15912340003', 95, 1);

INSERT INTO staff (staff_name, phone, role, work_status) VALUES
('张管理员', '13812340001', '管理员', '在岗'),
('李维修工', '13812340002', '维修工', '在岗');

INSERT INTO user_account (username, password, role, student_id, staff_id) VALUES
('zhangsan', '123456', '学生', '15220220241001', NULL),
('lisi', '123456', '学生', '15220220241002', NULL),
('admin', 'admin123', '管理员', NULL, 1),
('repair', 'repair123', '维修工', NULL, 2);

INSERT INTO service_station (station_name, campus_area, location, status, manager_id) VALUES
('图书馆服务点', '思明校区', '图书馆一楼大厅', '启用', 1),
('芙蓉湖服务点', '思明校区', '芙蓉湖凉亭', '启用', 1),
('海韵学生公寓', '思明校区', '海韵9号楼', '启用', NULL),
('翔安图书馆服务点', '翔安校区', '德旺图书馆一楼', '启用', NULL);

INSERT INTO item_type (type_name, deposit_amount, borrow_hours, description) VALUES
('雨伞', 20.00, 24, '长柄雨伞'),
('充电宝', 50.00, 12, '10000mAh'),
('工具箱', 100.00, 48, '包含螺丝刀、钳子等'),
('医药包', 30.00, 24, '简易急救包');

INSERT INTO item_asset (asset_code, status, purchase_date, type_id, station_id) VALUES
('UMB001', '可用', '2025-01-01', 1, 1),
('UMB002', '可用', '2025-01-01', 1, 1),
('UMB003', '可用', '2025-01-05', 1, 2),
('UMB004', '借出中', '2025-01-10', 1, 2),
('UMB005', '可用', '2025-01-15', 1, 4),
('PWR001', '可用', '2025-02-01', 2, 1),
('PWR002', '可用', '2025-02-01', 2, 2),
('PWR003', '维修中', '2025-02-10', 2, 1),
('BOX001', '可用', '2025-03-01', 3, 3),
('MED001', '可用', '2025-04-01', 4, 3);

INSERT INTO station_inventory (station_id, type_id, max_capacity, warning_line) VALUES
(1, 1, 10, 2),
(1, 2, 5, 1),
(2, 1, 8, 2),
(2, 2, 4, 1),
(3, 3, 3, 1),
(3, 4, 3, 1),
(4, 1, 15, 3);

INSERT INTO borrow_record (borrow_time, due_time, borrow_status, student_id, item_id, borrow_station_id) VALUES
(NOW(), DATE_ADD(NOW(), INTERVAL 24 HOUR), '借出中', '15220220241001', 1, 1),
(DATE_SUB(NOW(), INTERVAL 30 HOUR), DATE_SUB(NOW(), INTERVAL 6 HOUR), '借出中', '15220220241002', 7, 2),
(DATE_SUB(NOW(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 3 DAY), '已归还', '15220220241003', 3, 2);

UPDATE item_asset SET status = '借出中' WHERE item_id IN (1, 7);

UPDATE borrow_record 
SET return_time = DATE_SUB(NOW(), INTERVAL 2 DAY), 
    return_station_id = 2,
    borrow_status = '已归还'
WHERE borrow_id = 3;

INSERT INTO maintenance_record (problem_type, description, start_time, maintenance_status, item_id, staff_id) VALUES
('充电口损坏', '无法充电，插上无反应', NOW(), '待处理', 8, 2),
('伞骨断裂', '雨伞骨架断裂，无法正常使用', DATE_SUB(NOW(), INTERVAL 5 DAY), '已完成', 4, 2);

UPDATE maintenance_record 
SET end_time = DATE_SUB(NOW(), INTERVAL 2 DAY),
    maintenance_status = '已完成'
WHERE maintenance_id = 2;

UPDATE item_asset SET status = '可用' WHERE item_id = 4;

INSERT INTO credit_record (change_value, reason, student_id, related_borrow_id) VALUES
(-5, '逾期', '15220220241002', 2);

UPDATE student SET credit_score = 95 WHERE student_id = '15220220241002';

INSERT INTO operation_log (operation_type, operation_content, user_id) VALUES
('借出', '学生 15220220241001 在图书馆服务点借出雨伞 UMB001', 1),
('归还', '学生 15220220241003 在芙蓉湖服务点归还雨伞 UMB003', 1),
('维修登记', '充电宝 PWR003 登记维修，问题：充电口损坏', 4),
('维修完成', '雨伞 UMB004 维修完成，状态恢复可用', 4),
('登录', '用户 admin 登录系统', 3);
SELECT * FROM college;
SELECT * FROM student;
SELECT * FROM staff;
SELECT * FROM user_account;
SELECT * FROM service_station;
SELECT * FROM item_type;
SELECT * FROM item_asset;
SELECT * FROM station_inventory;
SELECT * FROM borrow_record;
SELECT * FROM maintenance_record;
SELECT * FROM credit_record;
SELECT * FROM operation_log;