USE xmu_borrowing_system;

DROP PROCEDURE IF EXISTS borrow_item;
DROP PROCEDURE IF EXISTS return_item;

DELIMITER //

CREATE PROCEDURE borrow_item(
    IN p_student_id VARCHAR(20),
    IN p_station_id INT,
    IN p_type_id INT
)
BEGIN
    DECLARE v_item_id INT DEFAULT NULL;
    DECLARE v_borrow_hours INT DEFAULT NULL;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_item_id = NULL;

    START TRANSACTION;

    SELECT item_id INTO v_item_id
    FROM item_asset
    WHERE station_id = p_station_id
      AND type_id = p_type_id
      AND status = '可用'
    LIMIT 1
    FOR UPDATE;

    IF v_item_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '该服务点暂无可用物资';
    ELSE
        SELECT borrow_hours INTO v_borrow_hours
        FROM item_type
        WHERE type_id = p_type_id;

        INSERT INTO borrow_record(
            student_id, item_id, borrow_station_id,
            borrow_time, due_time, borrow_status
        )
        VALUES(
            p_student_id, v_item_id, p_station_id,
            NOW(), DATE_ADD(NOW(), INTERVAL v_borrow_hours HOUR), '借出中'
        );

        UPDATE item_asset
        SET status = '借出中'
        WHERE item_id = v_item_id;

        COMMIT;
    END IF;
END //

CREATE PROCEDURE return_item(
    IN p_borrow_id INT,
    IN p_return_station_id INT
)
BEGIN
    DECLARE v_item_id INT DEFAULT NULL;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_item_id = NULL;

    START TRANSACTION;

    SELECT item_id INTO v_item_id
    FROM borrow_record
    WHERE borrow_id = p_borrow_id
      AND borrow_status = '借出中'
    FOR UPDATE;

    IF v_item_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '无效的借还记录或该记录已归还';
    ELSE
        UPDATE borrow_record
        SET return_station_id = p_return_station_id,
            return_time = NOW(),
            borrow_status = '已归还'
        WHERE borrow_id = p_borrow_id;

        UPDATE item_asset
        SET status = '可用',
            station_id = p_return_station_id
        WHERE item_id = v_item_id;

        COMMIT;
    END IF;
END //

DELIMITER ;