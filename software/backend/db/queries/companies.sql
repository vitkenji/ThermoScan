-- name: CreateCompany :one
INSERT INTO companies (
    name,
    address
) VALUES (
    $1,
    $2
)
RETURNING id, name, address, is_active, created_at, updated_at;

-- name: GetCompanyByID :one
SELECT id, name, address, is_active, created_at, updated_at
FROM companies
WHERE id = $1;

-- name: ListCompanies :many
SELECT id, name, address, is_active, created_at, updated_at
FROM companies
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: SetCompanyActiveStatus :one
UPDATE companies
SET is_active = $2
WHERE id = $1
RETURNING id, name, address, is_active, created_at, updated_at;
