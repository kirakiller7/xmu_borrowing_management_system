USE xmu_borrowing_system;

ALTER TABLE user_account
ADD CONSTRAINT uq_user_account_student UNIQUE (student_id),
ADD CONSTRAINT uq_user_account_staff UNIQUE (staff_id);

ALTER TABLE item_type
ADD CONSTRAINT chk_item_type_value
CHECK (deposit_amount >= 0 AND borrow_hours > 0);

ALTER TABLE station_inventory
ADD CONSTRAINT chk_inventory_value
CHECK (max_capacity >= 0 AND warning_line >= 0 AND warning_line <= max_capacity);

ALTER TABLE borrow_record
ADD CONSTRAINT chk_borrow_time
CHECK (
    due_time > borrow_time
    AND (return_time IS NULL OR return_time >= borrow_time)
);