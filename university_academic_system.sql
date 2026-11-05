CREATE DATABASE IF NOT EXISTS PAnand;
USE PAnand;

-- ================================================================
-- University Academic System SQL DDL, Procedures, Triggers, and Sample Data
-- ================================================================

-- ================================================================
-- 1. DATABASE SCHEMA (DDL)
-- ================================================================

-- Drop tables if they exist (clean start)
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS course_prerequisites;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS departments;

-- ------------------------------------------------
-- Departments Table
-- ------------------------------------------------
CREATE TABLE departments (
    department_id   INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) UNIQUE NOT NULL
);

-- ------------------------------------------------
-- Students Table
-- ------------------------------------------------
CREATE TABLE students (
    student_id      INT AUTO_INCREMENT PRIMARY KEY,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(100) UNIQUE NOT NULL,
    enrollment_date DATE DEFAULT CURRENT_DATE,
    cumulative_gpa  DECIMAL(3,2) DEFAULT 0.00
                         CHECK (cumulative_gpa >= 0.00 AND cumulative_gpa <= 4.00)
);

-- ------------------------------------------------
-- Courses Table
-- ------------------------------------------------
CREATE TABLE courses (
    course_id    INT AUTO_INCREMENT PRIMARY KEY,
    course_code  VARCHAR(20) UNIQUE NOT NULL,
    course_name  VARCHAR(100) NOT NULL,
    credits      INT NOT NULL CHECK (credits > 0),
    department_id INT,
    FOREIGN KEY (department_id)
        REFERENCES departments(department_id) ON DELETE CASCADE
);

-- ------------------------------------------------
-- Prerequisites Table (self‑referencing)
-- ------------------------------------------------
CREATE TABLE course_prerequisites (
    course_id               INT,
    prerequisite_course_id  INT,
    PRIMARY KEY (course_id, prerequisite_course_id),
    FOREIGN KEY (course_id)
        REFERENCES courses(course_id) ON DELETE CASCADE,
    FOREIGN KEY (prerequisite_course_id)
        REFERENCES courses(course_id) ON DELETE CASCADE,
    CHECK (course_id <> prerequisite_course_id)
);

-- ------------------------------------------------
-- Enrollments Table (tracks grades)
-- ------------------------------------------------
CREATE TABLE enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id    INT,
    course_id     INT,
    semester      VARCHAR(20) NOT NULL,
    grade         CHAR(1) NULL CHECK (grade IN ('A','B','C','D','F')),
    FOREIGN KEY (student_id)
        REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id)
        REFERENCES courses(course_id) ON DELETE CASCADE,
    UNIQUE (student_id, course_id)
);

-- ================================================================
-- 2. PREREQUISITE ENFORCEMENT PROCEDURE
-- ================================================================
DELIMITER //

CREATE PROCEDURE enroll_student(
    IN p_student_id INT,
    IN p_course_id  INT,
    IN p_semester   VARCHAR(20)
)
BEGIN
    DECLARE unmet_prereq INT;

    -- Count prerequisites that the student has NOT passed (A‑D are passing)
    SELECT COUNT(*) INTO unmet_prereq
    FROM course_prerequisites cp
    WHERE cp.course_id = p_course_id
      AND cp.prerequisite_course_id NOT IN (
          SELECT e.course_id
          FROM enrollments e
          WHERE e.student_id = p_student_id
            AND e.grade IN ('A','B','C','D')
      );

    IF unmet_prereq > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enrollment blocked: Student has not completed all prerequisites for this course.';
    END IF;

    -- Enroll the student (grade stays NULL = in progress)
    INSERT INTO enrollments (student_id, course_id, semester, grade)
    VALUES (p_student_id, p_course_id, p_semester, NULL);

    SELECT CONCAT('Successfully enrolled student ',
                  p_student_id,
                  ' in course ',
                  p_course_id) AS message;
END //

DELIMITER ;

-- ================================================================
-- 3. AUTOMATED GPA CALCULATION TRIGGERS
-- ================================================================
DELIMITER //

-- Helper procedure to recalculate a student's cumulative GPA
CREATE PROCEDURE recalculate_gpa(IN p_student_id INT)
BEGIN
    DECLARE new_gpa DECIMAL(3,2);

    SELECT COALESCE(
        SUM(
            CASE e.grade
                WHEN 'A' THEN 4.0
                WHEN 'B' THEN 3.0
                WHEN 'C' THEN 2.0
                WHEN 'D' THEN 1.0
                ELSE 0.0
            END * c.credits
        ) / NULLIF(SUM(c.credits), 0),
        0.00
    ) INTO new_gpa
    FROM enrollments e
    JOIN courses c ON e.course_id = c.course_id
    WHERE e.student_id = p_student_id
      AND e.grade IS NOT NULL;

    UPDATE students
    SET cumulative_gpa = ROUND(new_gpa, 2)
    WHERE student_id = p_student_id;
END //

-- Trigger after INSERT on enrollments
CREATE TRIGGER trg_update_gpa_insert
AFTER INSERT ON enrollments
FOR EACH ROW
BEGIN
    CALL recalculate_gpa(NEW.student_id);
END //

-- Trigger after UPDATE on enrollments
CREATE TRIGGER trg_update_gpa_update
AFTER UPDATE ON enrollments
FOR EACH ROW
BEGIN
    CALL recalculate_gpa(NEW.student_id);
END //

-- Trigger after DELETE on enrollments
CREATE TRIGGER trg_update_gpa_delete
AFTER DELETE ON enrollments
FOR EACH ROW
BEGIN
    CALL recalculate_gpa(OLD.student_id);
END //

DELIMITER ;

-- ================================================================
-- 4. SAMPLE DATA & TESTING SCRIPT
-- ================================================================
INSERT INTO departments (department_name) VALUES ('Computer Science');

INSERT INTO courses (course_code, course_name, credits, department_id) VALUES
('CS101', 'Intro to Programming',        4, 1),
('CS102', 'Data Structures & Algorithms',4, 1),
('CS201', 'Advanced Database Systems',   4, 1);

-- Prerequisites: CS101 → CS102 → CS201
INSERT INTO course_prerequisites (course_id, prerequisite_course_id) VALUES
(2, 1),  -- CS102 requires CS101
(3, 2);  -- CS201 requires CS102

INSERT INTO students (first_name, last_name, email) VALUES
('Alice', 'Smith', 'alice.smith@university.edu');

-- Test enrollment flow:
-- CALL enroll_student(1, 2, 'Fall 2026');   -- should fail (missing CS101)
CALL enroll_student(1, 1, 'Fall 2026');     -- enroll in CS101
UPDATE enrollments SET grade = 'A' WHERE student_id = 1 AND course_id = 1;

CALL enroll_student(1, 2, 'Spring 2027');   -- now succeeds because CS101 passed
UPDATE enrollments SET grade = 'B' WHERE student_id = 1 AND course_id = 2;

-- ================================================================
-- 5. GRADUATION AUDIT QUERY (CTE)
-- ================================================================
WITH student_credits AS (
    SELECT
        s.student_id,
        CONCAT(s.first_name, ' ', s.last_name) AS full_name,
        s.cumulative_gpa,
        SUM(c.credits) AS total_credits_earned
    FROM students s
    JOIN enrollments e ON s.student_id = e.student_id
    JOIN courses c     ON e.course_id = c.course_id
    WHERE e.grade IN ('A','B','C','D')
    GROUP BY s.student_id, s.first_name, s.last_name, s.cumulative_gpa
)
SELECT
    student_id,
    full_name,
    cumulative_gpa,
    total_credits_earned,
    CASE
        WHEN total_credits_earned >= 8 AND cumulative_gpa >= 2.0
            THEN 'ELIGIBLE FOR GRADUATION'
        ELSE 'PENDING REQUIREMENTS'
    END AS graduation_status
FROM student_credits;
