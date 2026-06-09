USE xmu_borrowing_system;

DELIMITER //

CREATE TRIGGER trg_borrow_record_after_update
AFTER UPDATE ON borrow_record
FOR EACH ROW
BEGIN
    DECLARE overdue_hours INT;
    IF OLD.borrow_status = '借出中' AND NEW.borrow_status = '已归还' THEN
        IF NEW.return_time > NEW.due_time THEN
            SET overdue_hours = TIMESTAMPDIFF(HOUR, NEW.due_time, NEW.return_time);
            INSERT INTO credit_record (student_id, change_value, reason, related_borrow_id)
            VALUES (NEW.student_id, -LEAST(overdue_hours, 20), '逾期', NEW.borrow_id);
            UPDATE student SET credit_score = GREATEST(credit_score - LEAST(overdue_hours, 20), 0)
            WHERE student_id = NEW.student_id;
        END IF;
    END IF;
END //

DELIMITER ;