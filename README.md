# University Academic System

A complete SQL-based database schema and business logic system for university academic tracking, prerequisite enforcement, automated GPA computation, and graduation auditing.

## 📌 Features

1. **Relational Database Design (DDL):**
   - `departments`: Academic departments.
   - `students`: Student profile tracking including dynamically calculated `cumulative_gpa`.
   - `courses`: Course catalogue associated with academic departments and credit counts.
   - `course_prerequisites`: Self-referencing table tracking prerequisite dependencies between courses.
   - `enrollments`: Enrollment records linking students to courses per semester with letter grades (`A`, `B`, `C`, `D`, `F`).

2. **Prerequisite Enforcement (`enroll_student` Procedure):**
   - Validates that a student has completed and passed all prerequisite courses (grades `A`-`D`) before allowing enrollment.
   - Raises a custom SQL exception (`SQLSTATE '45000'`) if any prerequisite is unmet.

3. **Automated GPA Calculation Triggers:**
   - Triggers for `AFTER INSERT`, `AFTER UPDATE`, and `AFTER DELETE` on the `enrollments` table automatically invoke `recalculate_gpa()`.
   - Calculates credit-weighted GPA on a 4.0 scale:
     - `A`: 4.0
     - `B`: 3.0
     - `C`: 2.0
     - `D`: 1.0
     - `F`: 0.0

4. **Graduation Audit Query:**
   - Common Table Expression (CTE) calculating total credits earned and cumulative GPA to determine if a student meets graduation criteria (e.g., $\ge 8$ credits and $\ge 2.0$ GPA).

---

## 🚀 Getting Started

### Prerequisites
- MySQL 8.0+ or compatible MariaDB server

### Execution
Run the script in MySQL CLI or MySQL Workbench:

```bash
mysql -u root -p < university_academic_system.sql
```

Alternatively, open your MySQL client:
```sql
SOURCE university_academic_system.sql;
```

---

## 🧪 Testing the Workflow

1. **Attempting Enrollment Without Prerequisites:**
   ```sql
   CALL enroll_student(1, 2, 'Fall 2026');
   -- Fails: "Enrollment blocked: Student has not completed all prerequisites for this course."
   ```

2. **Completing Prerequisite Course:**
   ```sql
   CALL enroll_student(1, 1, 'Fall 2026');
   UPDATE enrollments SET grade = 'A' WHERE student_id = 1 AND course_id = 1;
   ```

3. **Enrolling After Completing Prerequisite:**
   ```sql
   CALL enroll_student(1, 2, 'Spring 2027');
   UPDATE enrollments SET grade = 'B' WHERE student_id = 1 AND course_id = 2;
   ```

4. **Auditing Graduation Eligibility:**
   ```sql
   -- Runs the CTE graduation audit query
   SELECT * FROM students WHERE student_id = 1;
   ```
