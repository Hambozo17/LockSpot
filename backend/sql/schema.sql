-- =====================================================
-- LOCKSPOT DATABASE - Complete MySQL Schema
-- Version: 1.0
-- Normalized to 3NF with full constraints
-- =====================================================

-- Create and use database
DROP DATABASE IF EXISTS lockspot_db;
CREATE DATABASE lockspot_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE lockspot_db;

-- =====================================================
-- 1. USER TABLE
-- =====================================================
CREATE TABLE User (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Phone VARCHAR(20) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    UserType ENUM('Customer', 'Admin') DEFAULT 'Customer',
    PasswordHash VARCHAR(255) NOT NULL,
    IsVerified BOOLEAN DEFAULT FALSE,
    ProfileImageURL VARCHAR(500),
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_user_email (Email),
    UNIQUE KEY uk_user_phone (Phone),
    INDEX idx_user_email (Email),
    INDEX idx_user_type (UserType)
);

-- =====================================================
-- 2. LOCATION ADDRESS TABLE (3NF Normalization)
-- =====================================================
CREATE TABLE LocationAddress (
    AddressID INT AUTO_INCREMENT PRIMARY KEY,
    StreetAddress VARCHAR(255) NOT NULL,
    City VARCHAR(50) NOT NULL,
    State VARCHAR(50),
    ZipCode VARCHAR(10),
    Country VARCHAR(50) DEFAULT 'Egypt',
    Latitude DECIMAL(10, 8),
    Longitude DECIMAL(11, 8),
    
    INDEX idx_address_city (City),
    INDEX idx_address_coords (Latitude, Longitude)
);

-- =====================================================
-- 3. LOCKER LOCATION TABLE (Station/Cabinet Group)
-- =====================================================
CREATE TABLE LockerLocation (
    LocationID INT AUTO_INCREMENT PRIMARY KEY,
    AddressID INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    Description TEXT,
    ImageURL VARCHAR(500),
    OperatingHoursStart TIME DEFAULT '08:00:00',
    OperatingHoursEnd TIME DEFAULT '22:00:00',
    IsActive BOOLEAN DEFAULT TRUE,
    ContactPhone VARCHAR(20),
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_location_name (Name),
    FOREIGN KEY (AddressID) REFERENCES LocationAddress(AddressID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_location_active (IsActive)
);

-- =====================================================
-- 4. PRICING TIER TABLE (For Time-Based Pricing)
-- =====================================================
CREATE TABLE PricingTier (
    TierID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Size ENUM('Small', 'Medium', 'Large') NOT NULL,
    BasePrice DECIMAL(10, 2) NOT NULL DEFAULT 0,
    HourlyRate DECIMAL(10, 2) NOT NULL,
    DailyRate DECIMAL(10, 2) NOT NULL,
    WeeklyRate DECIMAL(10, 2),
    Description VARCHAR(255),
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_tier_name_size (Name, Size)
);

-- =====================================================
-- 5. LOCKER UNIT TABLE (Individual Locker Boxes)
-- =====================================================
CREATE TABLE LockerUnit (
    LockerID INT AUTO_INCREMENT PRIMARY KEY,
    LocationID INT NOT NULL,
    TierID INT NOT NULL,
    UnitNumber VARCHAR(10) NOT NULL,
    Size ENUM('Small', 'Medium', 'Large') NOT NULL,
    Status ENUM('Available', 'Booked', 'Maintenance', 'OutOfService') DEFAULT 'Available',
    QRCode VARCHAR(255),
    LastMaintenanceDate DATE,
    Notes TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_locker_qr (QRCode),
    UNIQUE KEY uk_locker_unit_location (LocationID, UnitNumber),
    
    FOREIGN KEY (LocationID) REFERENCES LockerLocation(LocationID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (TierID) REFERENCES PricingTier(TierID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_locker_status (Status),
    INDEX idx_locker_size (Size),
    INDEX idx_locker_location_status (LocationID, Status)
);

-- =====================================================
-- 6. DISCOUNT / PROMO CODE TABLE
-- =====================================================
CREATE TABLE Discount (
    DiscountID INT AUTO_INCREMENT PRIMARY KEY,
    Code VARCHAR(50) NOT NULL,
    Description VARCHAR(255),
    DiscountType ENUM('Percentage', 'FixedAmount') NOT NULL,
    DiscountValue DECIMAL(10, 2) NOT NULL,
    MinBookingAmount DECIMAL(10, 2) DEFAULT 0,
    MaxDiscountAmount DECIMAL(10, 2),
    ValidFrom DATETIME NOT NULL,
    ValidTo DATETIME NOT NULL,
    MaxUses INT,
    CurrentUses INT DEFAULT 0,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_discount_code (Code),
    INDEX idx_discount_valid (ValidFrom, ValidTo, IsActive),
    
    CONSTRAINT chk_discount_dates CHECK (ValidTo > ValidFrom),
    CONSTRAINT chk_discount_value CHECK (DiscountValue > 0)
);

-- =====================================================
-- 7. BOOKING TABLE (Main Transaction Table)
-- =====================================================
CREATE TABLE Booking (
    BookingID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    LockerID INT NOT NULL,
    DiscountID INT,
    StartTime DATETIME NOT NULL,
    EndTime DATETIME NOT NULL,
    BookingType ENUM('Storage', 'Delivery') DEFAULT 'Storage',
    SubtotalAmount DECIMAL(10, 2) NOT NULL,
    DiscountAmount DECIMAL(10, 2) DEFAULT 0,
    TotalAmount DECIMAL(10, 2) NOT NULL,
    Status ENUM('Pending', 'Confirmed', 'Active', 'Completed', 'Cancelled', 'Expired') DEFAULT 'Pending',
    CancellationReason TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (UserID) REFERENCES User(UserID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (LockerID) REFERENCES LockerUnit(LockerID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DiscountID) REFERENCES Discount(DiscountID)
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_booking_user (UserID),
    INDEX idx_booking_locker (LockerID),
    INDEX idx_booking_status (Status),
    INDEX idx_booking_dates (StartTime, EndTime),
    INDEX idx_booking_user_status (UserID, Status),
    INDEX idx_booking_locker_dates (LockerID, StartTime, EndTime),
    
    CONSTRAINT chk_booking_dates CHECK (EndTime > StartTime),
    CONSTRAINT chk_booking_amounts CHECK (TotalAmount >= 0 AND SubtotalAmount >= 0)
);

-- =====================================================
-- 8. PAYMENT METHOD TABLE (Saved Payment Methods)
-- =====================================================
CREATE TABLE PaymentMethod (
    MethodID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    MethodType ENUM('Visa', 'Mastercard', 'MobileWallet', 'Cash') NOT NULL,
    CardLastFour VARCHAR(4),
    CardHolderName VARCHAR(100),
    ExpiryMonth TINYINT,
    ExpiryYear SMALLINT,
    WalletPhone VARCHAR(20),
    IsDefault BOOLEAN DEFAULT FALSE,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (UserID) REFERENCES User(UserID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    INDEX idx_payment_method_user (UserID),
    INDEX idx_payment_method_default (UserID, IsDefault)
);

-- =====================================================
-- 9. PAYMENT TABLE (Transaction Records)
-- =====================================================
CREATE TABLE Payment (
    PaymentID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    MethodID INT,
    Amount DECIMAL(10, 2) NOT NULL,
    PaymentDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    TransactionReference VARCHAR(100),
    Status ENUM('Pending', 'Success', 'Failed', 'Refunded', 'PartialRefund') DEFAULT 'Pending',
    FailureReason VARCHAR(255),
    RefundAmount DECIMAL(10, 2),
    RefundDate TIMESTAMP NULL,
    ProcessedBy VARCHAR(50),
    
    UNIQUE KEY uk_payment_booking (BookingID),
    
    FOREIGN KEY (BookingID) REFERENCES Booking(BookingID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (MethodID) REFERENCES PaymentMethod(MethodID)
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_payment_status (Status),
    INDEX idx_payment_date (PaymentDate),
    INDEX idx_payment_reference (TransactionReference)
);

-- =====================================================
-- 10. STORED ITEM TABLE (Items in Locker)
-- =====================================================
CREATE TABLE StoredItem (
    ItemID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    Description VARCHAR(255) NOT NULL,
    Category ENUM('Luggage', 'Package', 'Electronics', 'Documents', 'Sports', 'Other') DEFAULT 'Other',
    PhotoURL VARCHAR(500),
    EstimatedValue DECIMAL(10, 2),
    Quantity INT DEFAULT 1,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (BookingID) REFERENCES Booking(BookingID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    INDEX idx_stored_item_booking (BookingID),
    INDEX idx_stored_item_category (Category)
);

-- =====================================================
-- 11. REVIEW TABLE (User Feedback)
-- =====================================================
CREATE TABLE Review (
    ReviewID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    Rating TINYINT NOT NULL,
    Title VARCHAR(100),
    Comment TEXT,
    IsVerified BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_review_booking (BookingID),
    
    FOREIGN KEY (BookingID) REFERENCES Booking(BookingID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    CONSTRAINT chk_rating_range CHECK (Rating >= 1 AND Rating <= 5),
    
    INDEX idx_review_rating (Rating),
    INDEX idx_review_date (CreatedAt)
);

-- =====================================================
-- 12. QR ACCESS CODE TABLE
-- =====================================================
CREATE TABLE QRAccessCode (
    QRID INT AUTO_INCREMENT PRIMARY KEY,
    BookingID INT NOT NULL,
    Code VARCHAR(255) NOT NULL,
    CodeType ENUM('Unlock', 'Lock', 'Emergency') DEFAULT 'Unlock',
    GeneratedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ExpiresAt DATETIME NOT NULL,
    UsedAt TIMESTAMP NULL,
    IsUsed BOOLEAN DEFAULT FALSE,
    
    UNIQUE KEY uk_qr_code (Code),
    
    FOREIGN KEY (BookingID) REFERENCES Booking(BookingID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    INDEX idx_qr_booking (BookingID),
    INDEX idx_qr_expires (ExpiresAt, IsUsed)
);

-- =====================================================
-- 13. NOTIFICATION TABLE
-- =====================================================
CREATE TABLE Notification (
    NotificationID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    Title VARCHAR(100) NOT NULL,
    Message TEXT NOT NULL,
    NotificationType ENUM('Booking', 'Payment', 'Reminder', 'Promo', 'System', 'Security') NOT NULL,
    RelatedBookingID INT,
    IsRead BOOLEAN DEFAULT FALSE,
    ReadAt TIMESTAMP NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (UserID) REFERENCES User(UserID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (RelatedBookingID) REFERENCES Booking(BookingID)
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_notification_user_read (UserID, IsRead),
    INDEX idx_notification_type (NotificationType),
    INDEX idx_notification_date (CreatedAt)
);

-- =====================================================
-- 14. AUDIT LOG TABLE (For Security & Tracking)
-- =====================================================
CREATE TABLE AuditLog (
    LogID BIGINT AUTO_INCREMENT PRIMARY KEY,
    UserID INT,
    Action VARCHAR(100) NOT NULL,
    TableName VARCHAR(50),
    RecordID INT,
    OldValues JSON,
    NewValues JSON,
    IPAddress VARCHAR(45),
    UserAgent VARCHAR(500),
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (UserID) REFERENCES User(UserID)
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_audit_user (UserID),
    INDEX idx_audit_action (Action),
    INDEX idx_audit_table (TableName),
    INDEX idx_audit_date (CreatedAt),
    INDEX idx_audit_record (TableName, RecordID)
);

-- =====================================================
-- VIEWS
-- =====================================================

-- View: Available Lockers with Full Details
CREATE OR REPLACE VIEW vw_AvailableLockers AS
SELECT 
    lu.LockerID,
    lu.UnitNumber,
    lu.Size,
    lu.Status,
    ll.LocationID,
    ll.Name AS LocationName,
    ll.Description AS LocationDescription,
    ll.ImageURL,
    ll.OperatingHoursStart,
    ll.OperatingHoursEnd,
    la.City,
    la.StreetAddress,
    la.Latitude,
    la.Longitude,
    pt.TierID,
    pt.HourlyRate,
    pt.DailyRate,
    pt.WeeklyRate
FROM LockerUnit lu
INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
INNER JOIN LocationAddress la ON ll.AddressID = la.AddressID
INNER JOIN PricingTier pt ON lu.TierID = pt.TierID
WHERE lu.Status = 'Available' 
  AND ll.IsActive = TRUE
  AND pt.IsActive = TRUE;

-- View: User Booking History with Complete Details
CREATE OR REPLACE VIEW vw_UserBookingHistory AS
SELECT 
    b.BookingID,
    b.UserID,
    CONCAT(u.FirstName, ' ', u.LastName) AS UserName,
    u.Email AS UserEmail,
    ll.Name AS LocationName,
    la.City,
    la.StreetAddress,
    lu.UnitNumber,
    lu.Size,
    b.StartTime,
    b.EndTime,
    TIMESTAMPDIFF(HOUR, b.StartTime, b.EndTime) AS DurationHours,
    b.BookingType,
    b.SubtotalAmount,
    b.DiscountAmount,
    b.TotalAmount,
    b.Status AS BookingStatus,
    b.CreatedAt AS BookingDate,
    p.PaymentID,
    p.Status AS PaymentStatus,
    p.PaymentDate,
    p.TransactionReference,
    r.Rating,
    r.Comment AS ReviewComment,
    d.Code AS DiscountCode
FROM Booking b
INNER JOIN User u ON b.UserID = u.UserID
INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
INNER JOIN LocationAddress la ON ll.AddressID = la.AddressID
LEFT JOIN Payment p ON b.BookingID = p.BookingID
LEFT JOIN Review r ON b.BookingID = r.BookingID
LEFT JOIN Discount d ON b.DiscountID = d.DiscountID;

-- View: Location Statistics Dashboard
CREATE OR REPLACE VIEW vw_LocationStatistics AS
SELECT 
    ll.LocationID,
    ll.Name AS LocationName,
    la.City,
    COUNT(DISTINCT lu.LockerID) AS TotalLockers,
    SUM(CASE WHEN lu.Status = 'Available' THEN 1 ELSE 0 END) AS AvailableLockers,
    SUM(CASE WHEN lu.Status = 'Booked' THEN 1 ELSE 0 END) AS BookedLockers,
    SUM(CASE WHEN lu.Status = 'Maintenance' THEN 1 ELSE 0 END) AS MaintenanceLockers,
    COUNT(DISTINCT b.BookingID) AS TotalBookings,
    COALESCE(SUM(p.Amount), 0) AS TotalRevenue,
    COALESCE(AVG(r.Rating), 0) AS AverageRating,
    COUNT(DISTINCT r.ReviewID) AS TotalReviews
FROM LockerLocation ll
INNER JOIN LocationAddress la ON ll.AddressID = la.AddressID
LEFT JOIN LockerUnit lu ON ll.LocationID = lu.LocationID
LEFT JOIN Booking b ON lu.LockerID = b.LockerID AND b.Status IN ('Completed', 'Active')
LEFT JOIN Payment p ON b.BookingID = p.BookingID AND p.Status = 'Success'
LEFT JOIN Review r ON b.BookingID = r.BookingID
WHERE ll.IsActive = TRUE
GROUP BY ll.LocationID, ll.Name, la.City;

-- View: Active Bookings (For Real-time Dashboard)
CREATE OR REPLACE VIEW vw_ActiveBookings AS
SELECT 
    b.BookingID,
    b.UserID,
    CONCAT(u.FirstName, ' ', u.LastName) AS UserName,
    u.Phone AS UserPhone,
    ll.Name AS LocationName,
    lu.UnitNumber,
    lu.Size,
    b.StartTime,
    b.EndTime,
    TIMESTAMPDIFF(MINUTE, NOW(), b.EndTime) AS MinutesRemaining,
    CASE 
        WHEN NOW() > b.EndTime THEN 'Overdue'
        WHEN TIMESTAMPDIFF(MINUTE, NOW(), b.EndTime) <= 30 THEN 'Expiring Soon'
        ELSE 'Active'
    END AS TimeStatus,
    b.TotalAmount
FROM Booking b
INNER JOIN User u ON b.UserID = u.UserID
INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
WHERE b.Status = 'Active'
ORDER BY b.EndTime ASC;

-- =====================================================
-- STORED PROCEDURES
-- =====================================================

DELIMITER //

-- Procedure: Create Booking with Concurrency Control & Double-Booking Prevention
CREATE PROCEDURE sp_CreateBooking(
    IN p_UserID INT,
    IN p_LockerID INT,
    IN p_StartTime DATETIME,
    IN p_EndTime DATETIME,
    IN p_BookingType VARCHAR(20),
    IN p_DiscountCode VARCHAR(50),
    OUT p_BookingID INT,
    OUT p_TotalAmount DECIMAL(10,2),
    OUT p_Status VARCHAR(50),
    OUT p_Message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_LockerStatus VARCHAR(20);
    DECLARE v_DiscountID INT DEFAULT NULL;
    DECLARE v_DiscountType VARCHAR(20);
    DECLARE v_DiscountValue DECIMAL(10,2);
    DECLARE v_DiscountAmount DECIMAL(10,2) DEFAULT 0;
    DECLARE v_SubtotalAmount DECIMAL(10,2);
    DECLARE v_HourlyRate DECIMAL(10,2);
    DECLARE v_DailyRate DECIMAL(10,2);
    DECLARE v_Hours INT;
    DECLARE v_Days INT;
    DECLARE v_ConflictCount INT;
    DECLARE v_MinBookingAmount DECIMAL(10,2);
    DECLARE v_MaxDiscountAmount DECIMAL(10,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_BookingID = NULL;
        SET p_TotalAmount = NULL;
        SET p_Status = 'ERROR';
        SET p_Message = 'Database error occurred during booking creation';
    END;
    
    -- Validate inputs
    IF p_StartTime >= p_EndTime THEN
        SET p_BookingID = NULL;
        SET p_TotalAmount = NULL;
        SET p_Status = 'VALIDATION_ERROR';
        SET p_Message = 'End time must be after start time';
        LEAVE proc_label;
    END IF;
    
    IF p_StartTime < NOW() THEN
        SET p_BookingID = NULL;
        SET p_TotalAmount = NULL;
        SET p_Status = 'VALIDATION_ERROR';
        SET p_Message = 'Cannot book in the past';
        LEAVE proc_label;
    END IF;
    
    START TRANSACTION;
    
    -- Lock the locker row to prevent concurrent bookings (FOR UPDATE)
    SELECT Status INTO v_LockerStatus 
    FROM LockerUnit 
    WHERE LockerID = p_LockerID 
    FOR UPDATE;
    
    IF v_LockerStatus IS NULL THEN
        SET p_BookingID = NULL;
        SET p_TotalAmount = NULL;
        SET p_Status = 'NOT_FOUND';
        SET p_Message = 'Locker not found';
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    IF v_LockerStatus != 'Available' THEN
        SET p_BookingID = NULL;
        SET p_TotalAmount = NULL;
        SET p_Status = 'UNAVAILABLE';
        SET p_Message = CONCAT('Locker is currently ', v_LockerStatus);
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    -- Check for overlapping bookings (double booking prevention)
    SELECT COUNT(*) INTO v_ConflictCount
    FROM Booking
    WHERE LockerID = p_LockerID
      AND Status IN ('Pending', 'Confirmed', 'Active')
      AND (
          (p_StartTime >= StartTime AND p_StartTime < EndTime) OR
          (p_EndTime > StartTime AND p_EndTime <= EndTime) OR
          (p_StartTime <= StartTime AND p_EndTime >= EndTime)
      );
    
    IF v_ConflictCount > 0 THEN
        SET p_BookingID = NULL;
        SET p_TotalAmount = NULL;
        SET p_Status = 'TIME_CONFLICT';
        SET p_Message = 'Selected time slot conflicts with existing booking';
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    -- Get pricing information
    SELECT pt.HourlyRate, pt.DailyRate INTO v_HourlyRate, v_DailyRate
    FROM LockerUnit lu
    INNER JOIN PricingTier pt ON lu.TierID = pt.TierID
    WHERE lu.LockerID = p_LockerID;
    
    -- Calculate duration and price
    SET v_Hours = CEIL(TIMESTAMPDIFF(MINUTE, p_StartTime, p_EndTime) / 60);
    SET v_Days = CEIL(v_Hours / 24);
    
    -- Use daily rate if more economical for long bookings
    IF v_Days >= 1 AND (v_Days * v_DailyRate) < (v_Hours * v_HourlyRate) THEN
        SET v_SubtotalAmount = v_Days * v_DailyRate;
    ELSE
        SET v_SubtotalAmount = v_Hours * v_HourlyRate;
    END IF;
    
    -- Apply discount if valid code provided
    IF p_DiscountCode IS NOT NULL AND TRIM(p_DiscountCode) != '' THEN
        SELECT 
            DiscountID, DiscountType, DiscountValue, MinBookingAmount, MaxDiscountAmount
        INTO 
            v_DiscountID, v_DiscountType, v_DiscountValue, v_MinBookingAmount, v_MaxDiscountAmount
        FROM Discount
        WHERE Code = UPPER(TRIM(p_DiscountCode))
          AND IsActive = TRUE
          AND NOW() BETWEEN ValidFrom AND ValidTo
          AND (MaxUses IS NULL OR CurrentUses < MaxUses);
        
        IF v_DiscountID IS NOT NULL AND v_SubtotalAmount >= v_MinBookingAmount THEN
            IF v_DiscountType = 'Percentage' THEN
                SET v_DiscountAmount = v_SubtotalAmount * (v_DiscountValue / 100);
            ELSE
                SET v_DiscountAmount = v_DiscountValue;
            END IF;
            
            -- Apply maximum discount cap
            IF v_MaxDiscountAmount IS NOT NULL AND v_DiscountAmount > v_MaxDiscountAmount THEN
                SET v_DiscountAmount = v_MaxDiscountAmount;
            END IF;
            
            -- Update discount usage counter
            UPDATE Discount SET CurrentUses = CurrentUses + 1 WHERE DiscountID = v_DiscountID;
        ELSE
            SET v_DiscountID = NULL;
            SET v_DiscountAmount = 0;
        END IF;
    END IF;
    
    -- Calculate final total
    SET p_TotalAmount = v_SubtotalAmount - v_DiscountAmount;
    IF p_TotalAmount < 0 THEN 
        SET p_TotalAmount = 0; 
    END IF;
    
    -- Create the booking
    INSERT INTO Booking (
        UserID, LockerID, DiscountID, StartTime, EndTime, 
        BookingType, SubtotalAmount, DiscountAmount, TotalAmount, Status
    ) VALUES (
        p_UserID, p_LockerID, v_DiscountID, p_StartTime, p_EndTime,
        IFNULL(p_BookingType, 'Storage'), v_SubtotalAmount, v_DiscountAmount, p_TotalAmount, 'Pending'
    );
    
    SET p_BookingID = LAST_INSERT_ID();
    
    -- Update locker status
    UPDATE LockerUnit SET Status = 'Booked' WHERE LockerID = p_LockerID;
    
    -- Create notification for user
    INSERT INTO Notification (UserID, Title, Message, NotificationType, RelatedBookingID)
    VALUES (p_UserID, 'Booking Created', 
            CONCAT('Your booking #', p_BookingID, ' has been created. Please complete payment within 15 minutes.'),
            'Booking', p_BookingID);
    
    SET p_Status = 'SUCCESS';
    SET p_Message = 'Booking created successfully';
    
    COMMIT;
END //

-- Procedure: Process Payment
CREATE PROCEDURE sp_ProcessPayment(
    IN p_BookingID INT,
    IN p_MethodID INT,
    IN p_TransactionReference VARCHAR(100),
    OUT p_PaymentID INT,
    OUT p_Status VARCHAR(50),
    OUT p_Message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_TotalAmount DECIMAL(10,2);
    DECLARE v_UserID INT;
    DECLARE v_ExistingPayment INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_PaymentID = NULL;
        SET p_Status = 'ERROR';
        SET p_Message = 'Database error occurred during payment processing';
    END;
    
    START TRANSACTION;
    
    -- Check if payment already exists
    SELECT PaymentID INTO v_ExistingPayment
    FROM Payment WHERE BookingID = p_BookingID;
    
    IF v_ExistingPayment IS NOT NULL THEN
        SET p_PaymentID = v_ExistingPayment;
        SET p_Status = 'ALREADY_PAID';
        SET p_Message = 'Payment already exists for this booking';
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    -- Get booking details
    SELECT Status, TotalAmount, UserID 
    INTO v_BookingStatus, v_TotalAmount, v_UserID
    FROM Booking 
    WHERE BookingID = p_BookingID
    FOR UPDATE;
    
    IF v_BookingStatus IS NULL THEN
        SET p_PaymentID = NULL;
        SET p_Status = 'NOT_FOUND';
        SET p_Message = 'Booking not found';
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    IF v_BookingStatus != 'Pending' THEN
        SET p_PaymentID = NULL;
        SET p_Status = 'INVALID_STATUS';
        SET p_Message = CONCAT('Cannot process payment. Booking status is: ', v_BookingStatus);
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    -- Create payment record (simulating successful payment)
    INSERT INTO Payment (BookingID, MethodID, Amount, TransactionReference, Status)
    VALUES (p_BookingID, p_MethodID, v_TotalAmount, 
            IFNULL(p_TransactionReference, CONCAT('TXN-', p_BookingID, '-', UNIX_TIMESTAMP())), 
            'Success');
    
    SET p_PaymentID = LAST_INSERT_ID();
    
    -- Update booking status
    UPDATE Booking SET Status = 'Confirmed' WHERE BookingID = p_BookingID;
    
    -- Create success notification
    INSERT INTO Notification (UserID, Title, Message, NotificationType, RelatedBookingID)
    VALUES (v_UserID, 'Payment Successful', 
            CONCAT('Payment of EGP ', v_TotalAmount, ' for booking #', p_BookingID, ' was successful.'),
            'Payment', p_BookingID);
    
    SET p_Status = 'SUCCESS';
    SET p_Message = 'Payment processed successfully';
    
    COMMIT;
END //

-- Procedure: Generate QR Access Code
CREATE PROCEDURE sp_GenerateQRCode(
    IN p_BookingID INT,
    IN p_CodeType VARCHAR(20),
    OUT p_QRID INT,
    OUT p_QRCode VARCHAR(255),
    OUT p_ExpiresAt DATETIME,
    OUT p_Status VARCHAR(50),
    OUT p_Message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_EndTime DATETIME;
    DECLARE v_UserID INT;
    
    SELECT Status, EndTime, UserID INTO v_BookingStatus, v_EndTime, v_UserID
    FROM Booking WHERE BookingID = p_BookingID;
    
    IF v_BookingStatus IS NULL THEN
        SET p_QRID = NULL;
        SET p_QRCode = NULL;
        SET p_Status = 'NOT_FOUND';
        SET p_Message = 'Booking not found';
        LEAVE proc_label;
    END IF;
    
    IF v_BookingStatus NOT IN ('Confirmed', 'Active') THEN
        SET p_QRID = NULL;
        SET p_QRCode = NULL;
        SET p_Status = 'INVALID_STATUS';
        SET p_Message = 'QR code can only be generated for confirmed or active bookings';
        LEAVE proc_label;
    END IF;
    
    -- Generate unique QR code
    SET p_QRCode = CONCAT(
        'LOCKSPOT-', 
        p_BookingID, '-',
        UPPER(IFNULL(p_CodeType, 'UNLOCK')), '-',
        DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-',
        LPAD(FLOOR(RAND() * 10000), 4, '0')
    );
    
    SET p_ExpiresAt = v_EndTime;
    
    INSERT INTO QRAccessCode (BookingID, Code, CodeType, ExpiresAt)
    VALUES (p_BookingID, p_QRCode, IFNULL(p_CodeType, 'Unlock'), p_ExpiresAt);
    
    SET p_QRID = LAST_INSERT_ID();
    SET p_Status = 'SUCCESS';
    SET p_Message = 'QR code generated successfully';
END //

-- Procedure: Cancel Booking
CREATE PROCEDURE sp_CancelBooking(
    IN p_BookingID INT,
    IN p_Reason TEXT,
    OUT p_RefundAmount DECIMAL(10,2),
    OUT p_Status VARCHAR(50),
    OUT p_Message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_BookingStatus VARCHAR(20);
    DECLARE v_LockerID INT;
    DECLARE v_UserID INT;
    DECLARE v_TotalAmount DECIMAL(10,2);
    DECLARE v_StartTime DATETIME;
    DECLARE v_HoursUntilStart INT;
    
    START TRANSACTION;
    
    SELECT Status, LockerID, UserID, TotalAmount, StartTime 
    INTO v_BookingStatus, v_LockerID, v_UserID, v_TotalAmount, v_StartTime
    FROM Booking 
    WHERE BookingID = p_BookingID
    FOR UPDATE;
    
    IF v_BookingStatus IS NULL THEN
        SET p_RefundAmount = NULL;
        SET p_Status = 'NOT_FOUND';
        SET p_Message = 'Booking not found';
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    IF v_BookingStatus IN ('Completed', 'Cancelled', 'Expired') THEN
        SET p_RefundAmount = NULL;
        SET p_Status = 'INVALID_STATUS';
        SET p_Message = CONCAT('Cannot cancel booking. Status is: ', v_BookingStatus);
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    -- Calculate refund based on cancellation timing
    SET v_HoursUntilStart = TIMESTAMPDIFF(HOUR, NOW(), v_StartTime);
    
    IF v_HoursUntilStart >= 24 THEN
        SET p_RefundAmount = v_TotalAmount; -- Full refund
    ELSEIF v_HoursUntilStart >= 2 THEN
        SET p_RefundAmount = v_TotalAmount * 0.5; -- 50% refund
    ELSE
        SET p_RefundAmount = 0; -- No refund
    END IF;
    
    -- Update booking status
    UPDATE Booking 
    SET Status = 'Cancelled', CancellationReason = p_Reason 
    WHERE BookingID = p_BookingID;
    
    -- Release locker
    UPDATE LockerUnit SET Status = 'Available' WHERE LockerID = v_LockerID;
    
    -- Process refund if applicable
    IF p_RefundAmount > 0 THEN
        UPDATE Payment 
        SET Status = 'Refunded', RefundAmount = p_RefundAmount, RefundDate = NOW()
        WHERE BookingID = p_BookingID;
    END IF;
    
    -- Create notification
    INSERT INTO Notification (UserID, Title, Message, NotificationType, RelatedBookingID)
    VALUES (v_UserID, 'Booking Cancelled', 
            CONCAT('Booking #', p_BookingID, ' has been cancelled. Refund: EGP ', p_RefundAmount),
            'Booking', p_BookingID);
    
    SET p_Status = 'SUCCESS';
    SET p_Message = CONCAT('Booking cancelled. Refund amount: EGP ', p_RefundAmount);
    
    COMMIT;
END //

-- Procedure: Get Location Revenue Report
CREATE PROCEDURE sp_GetLocationRevenueReport(
    IN p_LocationID INT,
    IN p_StartDate DATE,
    IN p_EndDate DATE
)
BEGIN
    SELECT 
        ll.LocationID,
        ll.Name AS LocationName,
        la.City,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(DISTINCT b.UserID) AS UniqueCustomers,
        SUM(CASE WHEN p.Status = 'Success' THEN p.Amount ELSE 0 END) AS TotalRevenue,
        SUM(CASE WHEN p.Status = 'Refunded' THEN p.RefundAmount ELSE 0 END) AS TotalRefunds,
        SUM(CASE WHEN p.Status = 'Success' THEN p.Amount ELSE 0 END) - 
            SUM(CASE WHEN p.Status = 'Refunded' THEN IFNULL(p.RefundAmount, 0) ELSE 0 END) AS NetRevenue,
        AVG(CASE WHEN p.Status = 'Success' THEN p.Amount END) AS AverageBookingValue,
        AVG(r.Rating) AS AverageRating,
        COUNT(r.ReviewID) AS TotalReviews,
        SUM(CASE WHEN b.Status = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledBookings,
        ROUND(SUM(CASE WHEN b.Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(b.BookingID), 2) AS CancellationRate
    FROM LockerLocation ll
    INNER JOIN LocationAddress la ON ll.AddressID = la.AddressID
    LEFT JOIN LockerUnit lu ON ll.LocationID = lu.LocationID
    LEFT JOIN Booking b ON lu.LockerID = b.LockerID 
        AND DATE(b.CreatedAt) BETWEEN IFNULL(p_StartDate, '2000-01-01') AND IFNULL(p_EndDate, '2099-12-31')
    LEFT JOIN Payment p ON b.BookingID = p.BookingID
    LEFT JOIN Review r ON b.BookingID = r.BookingID
    WHERE (p_LocationID IS NULL OR ll.LocationID = p_LocationID)
    GROUP BY ll.LocationID, ll.Name, la.City
    ORDER BY NetRevenue DESC;
END //

DELIMITER ;

-- =====================================================
-- TRIGGERS
-- =====================================================

DELIMITER //

-- Trigger: Auto-release locker when booking status changes
CREATE TRIGGER trg_AfterBookingStatusChange
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    IF NEW.Status IN ('Completed', 'Cancelled', 'Expired') 
       AND OLD.Status NOT IN ('Completed', 'Cancelled', 'Expired') THEN
        UPDATE LockerUnit SET Status = 'Available' WHERE LockerID = NEW.LockerID;
    END IF;
    
    IF NEW.Status = 'Active' AND OLD.Status != 'Active' THEN
        UPDATE LockerUnit SET Status = 'Booked' WHERE LockerID = NEW.LockerID;
    END IF;
END //

-- Trigger: Log booking changes to audit
CREATE TRIGGER trg_BookingAuditLog
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (UserID, Action, TableName, RecordID, OldValues, NewValues)
    VALUES (
        NEW.UserID, 
        'UPDATE_BOOKING', 
        'Booking', 
        NEW.BookingID,
        JSON_OBJECT(
            'Status', OLD.Status,
            'TotalAmount', OLD.TotalAmount
        ),
        JSON_OBJECT(
            'Status', NEW.Status,
            'TotalAmount', NEW.TotalAmount,
            'UpdatedAt', NEW.UpdatedAt
        )
    );
END //

-- Trigger: Enforce single default payment method per user
CREATE TRIGGER trg_BeforePaymentMethodInsert
BEFORE INSERT ON PaymentMethod
FOR EACH ROW
BEGIN
    IF NEW.IsDefault = TRUE THEN
        UPDATE PaymentMethod SET IsDefault = FALSE WHERE UserID = NEW.UserID;
    END IF;
END //

DELIMITER ;

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Sample Pricing Tiers
INSERT INTO PricingTier (Name, Size, BasePrice, HourlyRate, DailyRate, WeeklyRate, Description) VALUES
('Economy Small', 'Small', 0, 5.00, 25.00, 120.00, 'Compact locker for small bags and personal items'),
('Economy Medium', 'Medium', 0, 8.00, 40.00, 200.00, 'Standard locker for carry-on luggage'),
('Economy Large', 'Large', 0, 12.00, 60.00, 300.00, 'Spacious locker for large suitcases'),
('Premium Small', 'Small', 5.00, 7.00, 35.00, 170.00, 'Climate-controlled small locker'),
('Premium Medium', 'Medium', 5.00, 10.00, 50.00, 250.00, 'Climate-controlled medium locker'),
('Premium Large', 'Large', 5.00, 15.00, 75.00, 375.00, 'Climate-controlled large locker');

-- Sample Addresses
INSERT INTO LocationAddress (StreetAddress, City, State, ZipCode, Country, Latitude, Longitude) VALUES
('Al Ahram Street, Pyramids Area', 'Giza', 'Giza', '12511', 'Egypt', 29.97916, 31.13428),
('Terminal 3, Cairo International Airport', 'Cairo', 'Cairo', '11432', 'Egypt', 30.12190, 31.40566),
('City Stars Mall, Omar Ibn Khattab Street', 'Cairo', 'Cairo', '11371', 'Egypt', 30.07333, 31.34560),
('Khan El-Khalili, Al-Muizz Street', 'Cairo', 'Cairo', '11511', 'Egypt', 30.04782, 31.26231),
('Alexandria Library, Corniche Road', 'Alexandria', 'Alexandria', '21526', 'Egypt', 31.20885, 29.90920);

-- Sample Locker Locations
INSERT INTO LockerLocation (AddressID, Name, Description, OperatingHoursStart, OperatingHoursEnd, ContactPhone) VALUES
(1, 'Giza Pyramids Entrance', 'Secure luggage storage near the main pyramids entrance. Perfect for tourists.', '06:00:00', '22:00:00', '+20-2-3383-8823'),
(2, 'Cairo Airport Terminal 3', '24/7 secure storage facility at the international terminal.', '00:00:00', '23:59:59', '+20-2-2265-5000'),
(3, 'City Stars Mall', 'Convenient shopping companion storage in Egypt largest mall.', '10:00:00', '23:00:00', '+20-2-2480-0500'),
(4, 'Khan El-Khalili Market', 'Store your bags while exploring the historic bazaar.', '09:00:00', '21:00:00', '+20-2-2590-3788'),
(5, 'Bibliotheca Alexandrina', 'Cultural hub storage for library and museum visitors.', '10:00:00', '19:00:00', '+20-3-4839-999');

-- Sample Locker Units (10+ lockers per location)
INSERT INTO LockerUnit (LocationID, TierID, UnitNumber, Size, Status, QRCode) VALUES
-- Giza Pyramids (Location 1)
(1, 1, 'A-001', 'Small', 'Available', 'QR-GIZ-A001'),
(1, 1, 'A-002', 'Small', 'Available', 'QR-GIZ-A002'),
(1, 1, 'A-003', 'Small', 'Available', 'QR-GIZ-A003'),
(1, 2, 'B-001', 'Medium', 'Available', 'QR-GIZ-B001'),
(1, 2, 'B-002', 'Medium', 'Available', 'QR-GIZ-B002'),
(1, 3, 'C-001', 'Large', 'Available', 'QR-GIZ-C001'),
(1, 3, 'C-002', 'Large', 'Available', 'QR-GIZ-C002'),
-- Cairo Airport (Location 2)
(2, 4, 'A-001', 'Small', 'Available', 'QR-CAI-A001'),
(2, 4, 'A-002', 'Small', 'Available', 'QR-CAI-A002'),
(2, 5, 'B-001', 'Medium', 'Available', 'QR-CAI-B001'),
(2, 5, 'B-002', 'Medium', 'Available', 'QR-CAI-B002'),
(2, 5, 'B-003', 'Medium', 'Available', 'QR-CAI-B003'),
(2, 6, 'C-001', 'Large', 'Available', 'QR-CAI-C001'),
(2, 6, 'C-002', 'Large', 'Available', 'QR-CAI-C002'),
-- City Stars (Location 3)
(3, 1, 'A-001', 'Small', 'Available', 'QR-CIT-A001'),
(3, 1, 'A-002', 'Small', 'Available', 'QR-CIT-A002'),
(3, 2, 'B-001', 'Medium', 'Available', 'QR-CIT-B001'),
(3, 2, 'B-002', 'Medium', 'Available', 'QR-CIT-B002'),
(3, 3, 'C-001', 'Large', 'Available', 'QR-CIT-C001'),
-- Khan El-Khalili (Location 4)
(4, 1, 'A-001', 'Small', 'Available', 'QR-KHN-A001'),
(4, 1, 'A-002', 'Small', 'Available', 'QR-KHN-A002'),
(4, 2, 'B-001', 'Medium', 'Available', 'QR-KHN-B001'),
(4, 3, 'C-001', 'Large', 'Available', 'QR-KHN-C001'),
-- Alexandria Library (Location 5)
(5, 1, 'A-001', 'Small', 'Available', 'QR-ALX-A001'),
(5, 2, 'B-001', 'Medium', 'Available', 'QR-ALX-B001'),
(5, 3, 'C-001', 'Large', 'Available', 'QR-ALX-C001');

-- Sample Discount Codes
INSERT INTO Discount (Code, Description, DiscountType, DiscountValue, MinBookingAmount, MaxDiscountAmount, ValidFrom, ValidTo, MaxUses) VALUES
('WELCOME10', 'Welcome discount - 10% off your first booking', 'Percentage', 10.00, 20.00, 50.00, NOW(), DATE_ADD(NOW(), INTERVAL 1 YEAR), 1000),
('FLAT25', 'Flat EGP 25 off any booking over EGP 50', 'FixedAmount', 25.00, 50.00, NULL, NOW(), DATE_ADD(NOW(), INTERVAL 6 MONTH), 500),
('SUMMER20', 'Summer special - 20% off', 'Percentage', 20.00, 30.00, 100.00, NOW(), DATE_ADD(NOW(), INTERVAL 3 MONTH), 200),
('TOURIST15', 'Tourist special - 15% off at popular destinations', 'Percentage', 15.00, 25.00, 75.00, NOW(), DATE_ADD(NOW(), INTERVAL 1 YEAR), NULL),
('LOYAL50', 'Loyalty reward - EGP 50 off', 'FixedAmount', 50.00, 100.00, NULL, NOW(), DATE_ADD(NOW(), INTERVAL 1 YEAR), 100);

-- Sample Users (for testing)
INSERT INTO User (FirstName, LastName, Phone, Email, UserType, PasswordHash, IsVerified) VALUES
('Ahmed', 'Mohamed', '+201001234567', 'ahmed@example.com', 'Customer', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.V5.LQKQz.5KVUK', TRUE),
('Sara', 'Ali', '+201112345678', 'sara@example.com', 'Customer', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.V5.LQKQz.5KVUK', TRUE),
('Admin', 'User', '+201234567890', 'admin@lockspot.com', 'Admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.V5.LQKQz.5KVUK', TRUE);

-- =====================================================
-- QUERY OPTIMIZATION EXAMPLES (FOR PRESENTATION)
-- =====================================================

-- Show query execution plan
-- EXPLAIN SELECT * FROM Booking WHERE UserID = 1 AND Status = 'Active';
-- EXPLAIN SELECT * FROM LockerUnit WHERE LocationID = 1 AND Status = 'Available' AND Size = 'Medium';

-- Index usage verification
-- SHOW INDEX FROM Booking;
-- SHOW INDEX FROM LockerUnit;

-- =====================================================
-- END OF SCHEMA
-- =====================================================
