# Flutter App (`app`)

Ung dung Flutter cho he thong quan ly du an va cong viec noi bo.

## Cai dat

1. Copy file moi truong:
   - Da co san `app/.env` cho local.
   - Mau: `app/.env.example`.
2. Cai package:
   ```bash
   flutter pub get
   ```
3. Chay app:
   ```bash
   flutter run
   ```

## Bien moi truong

- `APP_NAME`: ten app.
- `API_BASE_URL`: URL API Laravel (mac dinh `http://127.0.0.1:8000/api/v1`).
- `WEB_BASE_URL`: URL web Laravel React.
- `REQUEST_TIMEOUT_SECONDS`: timeout request.

## Luong man hinh

- **Chua dang nhap:** Man dau la man **Dang nhap** full man (email, mat khau, nut Dang nhap). Token luu bang `flutter_secure_storage`, tu khoi phuc session khi mo lai app.
- **Da dang nhap:** Vao **Dashboard** voi **chan man hinh (bottom navigation)** 4 tab: **Tong quan**, **Cong viec**, **Modules**, **Tai khoan**. Tat ca chuc nang goi API web (Laravel).

## Trang thai hien tai

- Bootstrap app, tich hop `flutter_dotenv`; sau khoi dong kiem tra token, neu co va hop le thi vao dashboard, neu khong thi hien man dang nhap.
- Tab **Tong quan**: Chi so nhanh tu `GET /api/v1/public/summary` (du an/task/han/ty le dung han).
- Tab **Tong quan** hien thi them danh sach nhan su qua tai (workload overload).
- Tab **Cong viec** (thao tac that qua API):
  - Tai danh sach task tu `GET /api/v1/tasks` (can token)
  - Loc theo trang thai task
  - Cap nhat trang thai truc tiep qua `PUT /api/v1/tasks/{id}`
- Tab **Modules**: Mo cac man Thong bao, Lich hop, CRM, Bao cao, Workflow dich vu (tat ca goi API web).
- Tab **Tai khoan**: Thong tin user dang nhap, nut Dang xuat; dang nhap thuc hien o man dau khi chua co token (`POST /api/v1/login`, `GET /api/v1/me`, `POST /api/v1/logout`).
- Notification Center tren mobile da ho tro:
  - Danh dau tung thong bao da doc
  - Danh dau tat ca thong bao da doc
- Meetings tren mobile da nang cap:
  - Loc theo tu khoa + khoang ngay (`search`, `date_from`, `date_to`)
  - Tao lich hop co them truong `ghi chu`
  - Xac nhan truoc khi xoa lich hop
- CRM mini tren mobile da co:
  - Tim kiem nhanh khach hang/thanh toan
  - Keo de refresh du lieu
  - The thong ke nhanh so luong khach hang va giao dich
- Meetings tren mobile da bo sung sua/xoa theo role:
  - Vai tro `admin`, `quan_ly` duoc tao/sua
  - Xoa chi cho `admin`
- CRM tren mobile da co CRUD co ban theo role:
  - Khach hang cho phep tao/sua voi `admin`, `quan_ly`, `nhan_vien`
  - Thanh toan cho phep tao/sua voi `admin`, `ke_toan`
  - Xoa chi cho `admin`
  - App tu dong an/hien nut thao tac theo role dang dang nhap
- Services module tren mobile da co CRUD form theo tung workflow:
  - Backlinks / Content / Audit / Website-care
  - Co phan quyen thao tac: tao/sua (`admin`, `quan_ly`), xoa (`admin`)
- Task module tren mobile da co "Task center":
  - Comment trong task (them/xoa)
  - Attachment (them/xoa link hoặc upload file thật)
  - Reminder (them/xoa theo role `admin`, `quan_ly`)
  - File picker cho comment/attachment để upload trực tiếp
- Da bo sung UX picker ngay/gio:
  - Meetings: chon ngay cho bo loc `tu ngay/den ngay`, chon ngay gio cho `thoi gian hop`
  - Task center: chon ngay gio cho reminder, va ho tro sua reminder truc tiep
- Services module da bo sung:
  - Date picker cho cac truong ngay (`report_date`, `check_date`)
  - Badge mau theo status tren tung ban ghi de theo doi nhanh
- Contracts mobile da duoc dong bo lai UI form tao/sua:
  - Bottom sheet sua hop dong chia thanh section card dong bo voi cac man hinh khac
  - Trang thai hop dong chi hien thi read-only theo nghiep vu tu dong
  - Danh sach san pham / thu / chi hien thi theo card ro rang hon, de thao tac tren dien thoai
  - Luong duyet hop dong co them thao tac "khong duyet"; status tu dong suy ra `draft / signed / active / expired / success / cancelled`
