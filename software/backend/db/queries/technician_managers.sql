-- name: AddTechnicianManager :one
INSERT INTO technician_managers (
    company_id,
    technician_id,
    manager_id
) VALUES (
    $1,
    $2,
    $3
)
RETURNING company_id, technician_id, manager_id, created_at;

-- name: RemoveTechnicianManager :exec
DELETE FROM technician_managers
WHERE company_id = $1
  AND technician_id = $2
  AND manager_id = $3;

-- name: CountManagersForTechnician :one
SELECT count(*)
FROM technician_managers
WHERE company_id = $1
  AND technician_id = $2;

-- name: ListManagersByTechnician :many
SELECT
    u.id,
    u.company_id,
    u.name,
    u.email,
    u.role,
    u.is_active,
    u.is_default_manager,
    tm.created_at AS assigned_at
FROM technician_managers tm
JOIN users u ON u.company_id = tm.company_id AND u.id = tm.manager_id
WHERE tm.company_id = $1
  AND tm.technician_id = $2
ORDER BY tm.created_at ASC;

-- name: ListTechniciansByManager :many
SELECT
    u.id,
    u.company_id,
    u.name,
    u.email,
    u.role,
    u.is_active,
    tm.created_at AS assigned_at
FROM technician_managers tm
JOIN users u ON u.company_id = tm.company_id AND u.id = tm.technician_id
WHERE tm.company_id = $1
  AND tm.manager_id = $2
ORDER BY tm.created_at ASC;
