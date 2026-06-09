USE xmu_borrowing_system;
CREATE INDEX idx_student_college ON student(college_id);
CREATE INDEX idx_item_station_type_status ON item_asset(station_id, type_id, status);
CREATE INDEX idx_borrow_student_status ON borrow_record(student_id, borrow_status);
CREATE INDEX idx_borrow_due_time ON borrow_record(due_time);
CREATE INDEX idx_maintenance_item ON maintenance_record(item_id);