-- 016_performance_indexes.sql
-- Non-destructive performance index optimizations for attendance, retention cases, and payments.

create index if not exists idx_no_show_gym_status_created on no_show_cases(gym_id, status, created_at desc);
create index if not exists idx_payments_gym_status_created on payments(gym_id, status, created_at desc);
create index if not exists idx_attendance_gym_member_checkin on attendance(gym_id, member_id, check_in_at desc);
