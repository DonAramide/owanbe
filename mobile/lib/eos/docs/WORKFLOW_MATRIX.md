# Workflow Matrix

Maps admin actions to audit scopes and platform state transitions:

| Admin Trigger | API Endpoint Called | Audit Transition | Notification Target |
| :--- | :--- | :--- | :--- |
| Suspend User | `/users/:id/suspend` | `SUSPEND_USER` | Target User (Push/Email) |
| Approve Vendor | `/vendors/:id/approve` | `APPROVE_ONBOARDING` | Target Vendor (In-App) |
| Dispatch Broadcast | `/broadcasts/dispatch` | `BROADCAST_ALL` | Targeted Audience |
| Maintenance Mode | `/platform/maintenance`| `LOCKDOWN_SYSTEM` | System Admins (Email Alert) |
