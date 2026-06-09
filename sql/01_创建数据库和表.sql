CREATE DATABASE  xmu_borrowing_system
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
use xmu_borrowing_system;
CREATE TABLE college (
    college_id INT PRIMARY KEY AUTO_INCREMENT,
    college_name VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20)
);
CREATE TABLE student (
    student_id VARCHAR(20) PRIMARY KEY,
    student_name VARCHAR(50) NOT NULL,
    gender ENUM('男','女') NOT NULL,
    phone VARCHAR(20) NOT NULL,
    credit_score INT DEFAULT 100 CHECK (credit_score BETWEEN 0 AND 100),
    college_id INT NOT NULL,                      
    FOREIGN KEY (college_id) REFERENCES college(college_id)
);
CREATE TABLE staff (
    staff_id INT PRIMARY KEY AUTO_INCREMENT,
    staff_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    role ENUM('管理员', '维修工') NOT NULL,
    work_status ENUM('在岗', '离岗') DEFAULT '在岗'
);
CREATE TABLE user_account (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('学生', '管理员', '维修工') NOT NULL,
    status ENUM('正常', '锁定') DEFAULT '正常',
    student_id VARCHAR(20),
    staff_id INT,
    FOREIGN KEY (student_id) REFERENCES student(student_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
    CHECK (
        (role = '学生' AND student_id IS NOT NULL AND staff_id IS NULL) OR
        (role IN ('管理员','维修工') AND staff_id IS NOT NULL AND student_id IS NULL) 
    )
);
CREATE TABLE service_station (
    station_id INT PRIMARY KEY AUTO_INCREMENT,
    station_name VARCHAR(100) NOT NULL,
    campus_area ENUM('思明校区', '翔安校区') NOT NULL,
    location VARCHAR(200),
    status ENUM('启用', '停用') DEFAULT '启用',
    manager_id INT,
    FOREIGN KEY (manager_id) REFERENCES staff(staff_id)
);
CREATE TABLE item_type (
    type_id INT PRIMARY KEY AUTO_INCREMENT,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    deposit_amount DECIMAL(10,2) DEFAULT 0.00,
    borrow_hours INT NOT NULL DEFAULT 24,
    description TEXT
);
CREATE TABLE item_asset (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    asset_code VARCHAR(50) UNIQUE NOT NULL,
    status ENUM('可用','借出中','维修中','报废') DEFAULT '可用',
    purchase_date DATE,
    type_id INT NOT NULL,
    station_id INT,
    FOREIGN KEY (type_id) REFERENCES item_type(type_id),
    FOREIGN KEY (station_id) REFERENCES service_station(station_id)
);
CREATE TABLE station_inventory (
    station_id INT NOT NULL,
    type_id INT NOT NULL,
    max_capacity INT NOT NULL,
    warning_line INT NOT NULL,
    PRIMARY KEY (station_id, type_id),
    FOREIGN KEY (station_id) REFERENCES service_station(station_id),
    FOREIGN KEY (type_id) REFERENCES item_type(type_id)
);
CREATE TABLE borrow_record (
    borrow_id INT PRIMARY KEY AUTO_INCREMENT,
    borrow_time DATETIME NOT NULL,
    due_time DATETIME NOT NULL,
    return_time DATETIME,
    borrow_status ENUM('借出中', '已归还', '逾期') DEFAULT '借出中',
    overdue_fee DECIMAL(10,2) DEFAULT 0.00,
    student_id VARCHAR(20) NOT NULL,
    item_id INT NOT NULL,
    borrow_station_id INT NOT NULL,
    return_station_id INT,
    FOREIGN KEY (student_id) REFERENCES student(student_id),
    FOREIGN KEY (item_id) REFERENCES item_asset(item_id),
    FOREIGN KEY (borrow_station_id) REFERENCES service_station(station_id),
    FOREIGN KEY (return_station_id) REFERENCES service_station(station_id)
);
CREATE TABLE maintenance_record (
    maintenance_id INT PRIMARY KEY AUTO_INCREMENT,
    problem_type VARCHAR(50),
    description TEXT,
    start_time DATETIME,
    end_time DATETIME,
    maintenance_status ENUM('待处理', '处理中', '已完成', '报废') DEFAULT '待处理',
    item_id INT NOT NULL,
    staff_id INT,
    FOREIGN KEY (item_id) REFERENCES item_asset(item_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);
CREATE TABLE credit_record (
    credit_id INT PRIMARY KEY AUTO_INCREMENT,
    change_value INT NOT NULL,
    reason ENUM('逾期', '损坏', '人工调整') NOT NULL,
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    student_id VARCHAR(20) NOT NULL,
    related_borrow_id INT,
    FOREIGN KEY (student_id) REFERENCES student(student_id),
    FOREIGN KEY (related_borrow_id) REFERENCES borrow_record(borrow_id)
);
CREATE TABLE operation_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    operation_type VARCHAR(50),
    operation_content TEXT,
    operation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INT,
    FOREIGN KEY (user_id) REFERENCES user_account(user_id)
);