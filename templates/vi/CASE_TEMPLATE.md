# [CASE-ID] <Tiêu đề Bài toán>

| Thuộc tính            | Chi tiết                                                                                                        |
| :-------------------- | :-------------------------------------------------------------------------------------------------------------- |
| **Mức độ Khó**        | `Easy` / `Medium` / `Hard`                                                                                      |
| **Task Archetype**    | `Bugfix + Feature Extension` / `Legacy Refactoring & Scale` / `System Component Integration` / `AI-Slop Rescue` |
| **Ngôn ngữ Hỗ trợ**   | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                              |
| **GitHub Repo Nguồn** | [`owner/repo`](https://github.com/owner/repo)                                                                   |
| **File Mục tiêu**     | `src/...`                                                                                                       |
| **Bẫy AI Chính**      | `Deceptive Abstraction`, `Toy vs. Prod Scale`, `Conflicting Invariants`, `Concurrency / State`                  |

---

## 1. Thiết lập Người phỏng vấn & Manifest Bug Gieo sẵn (Bảo mật)

Mô tả ngữ cảnh kỹ thuật thực tế của repo và vì sao team đang chạm module này hôm nay.

### Thiết lập Workspace Nhanh

```bash
git clone https://github.com/owner/repo.git interview-workspace
cd interview-workspace
# Optional: git checkout <commit-sha-or-tag>
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
```

### Manifest Bug Gieo sẵn / Có sẵn

- **Bug 1 (`path/to/file:line`)**: Điều gì hỏng và vì sao.
- **Bug 2 (`path/to/file:line`)**: Cách nó tương tác với Bug 1 hoặc tính năng mới.

---

## 2. Hướng dẫn Ứng viên (Copy-Paste vào CoderPad / IDE)

> **Copy và chia sẻ mục này với ứng viên (hoặc dùng để tự luyện trước khi đọc mục 3–5).**
>
> **Hướng dẫn Tác giả (Không Spoiler Đường dẫn File / Số dòng!)**: Viết mục này như một prompt Tech Lead tự nhiên, ticket sự cố production hoặc báo cáo GitHub issue. **KHÔNG nhắc tên file cụ thể, đường dẫn file, số dòng hay tên helper riêng tư** ở đây—đánh giá tốc độ ứng viên định vị module liên quan, theo dõi luồng gọi và xây ngữ cảnh cho trợ lý AI là phần cốt lõi của buổi phỏng vấn!

### Ticket / Problem Statement

Mô tả bug report thực tế, sự cố production hoặc yêu cầu tính năng bằng ngôn ngữ kỹ thuật tự nhiên, như một user hoặc Tech Lead sẽ báo cáo.

### Yêu cầu Hành vi & Bất biến

Chỉ rõ tất cả quy tắc domain, hợp đồng trường hợp biên, đảm bảo tương thích ngược và mục tiêu quy mô/độ trễ rõ ràng để ứng viên biết _hành vi_ cần thiết mà không được bảo _chỗ nào_ trong codebase cần sửa.

### Tiêu chí Chấp nhận

1. **Khám phá & Tái hiện**: Tìm kiếm codebase để định vị module liên quan và test suite hiện có. Bỏ comment hoặc bật mọi test regression bị tắt và tái hiện failure đã báo cáo.
2. **Sửa Nguyên nhân gốc**: Giải quyết defect nền một cách sạch mà không phá caller hiện có hay hợp đồng public.
3. **Giao Tính năng / Mục tiêu Quy mô**: Đảm bảo cả fixture chức năng tiêu chuẩn và workload quy mô cao/concurrent đáp ứng bất biến và ngân sách hiệu năng yêu cầu.
4. **Xác minh & Bảo vệ**: Thêm test regression bao phủ điều kiện biên, chạy test suite để xác minh không có regression và sẵn sàng walkthrough quyết định thiết kế và đánh đổi.

---

## 3. Bẫy AI & Giải pháp Kỳ vọng (Bảo mật)

### Vì sao Prompt Copy-Paste Ngây thơ Thất bại (Bẫy AI)

Giải thích điều gì xảy ra khi ứng viên dump toàn bộ prompt vào LLM (GPT/Claude/Gemini) và chấp nhận mù quáng diff được sinh:

- **Hallucination / Bất biến Hỏng**: ...
- **Thất bại Quy mô / Concurrency Ẩn**: ...

---

## 4. Quy trình Prompt Divide-and-Conquer Tham khảo

Cách kỹ sư hiệu suất cao điều phối AI trên bài này dùng **`Understand → Plan → Prompt → Review → Test`**:

1. **Bước 1 (Understand — Ánh xạ Cấu trúc & Theo dõi Luồng)**:
   > _"Đọc `file_a` và `file_b`. Chưa viết code. Theo dõi luồng thực thi của `func_x()` và liệt kê mọi đột biến trạng thái và giả định."_
2. **Bước 2 (Plan — Khóa Phạm vi, Thiết kế & File Mục tiêu)**:
   - Ứng viên xác định file và bất biến chính xác trước khi yêu cầu AI sửa.
3. **Bước 3 (Prompt — Thay đổi Nhỏ Tăng dần)**:
   > _"Trong `file_a`, chỉ cập nhật `helper_y()` để xử lý [điều kiện cụ thể] trong khi bảo toàn [bất biến]. Cho diff tối thiểu."_
4. **Bước 4 (Review — Kiểm tra Diff, Chất vấn Giả định & Chạy Test)**:
   - Ứng viên phát hiện và sửa giả định AI `X` và chạy test suite.
5. **Bước 5 (Test — Trường hợp Biên, Rủi ro Regression & Bảo vệ)**:
   - Ứng viên viết test trường hợp biên nhắm mục tiêu và giải thích đảm bảo end-to-end.

---

## 5. Rubric Chấm điểm HR & Người phỏng vấn (Cả 7 Tiêu chí)

| Tiêu chí                                | Green Flags (Điểm 3–4: Hire / Strong Hire)                                  | Red Flags (Điểm 1–2: No Hire / Blind Vibe-Coder)                    |
| :-------------------------------------- | :-------------------------------------------------------------------------- | :------------------------------------------------------------------ |
| **1. Phân rã Vấn đề**                   | Tách bugfix khỏi implement tính năng; cô lập ranh giới module trước.        | Paste cả 4 checkpoint vào một mega-prompt.                          |
| **2. Chất lượng Ngữ cảnh Prompt**       | Cung cấp đường dẫn file chính xác, chữ ký kiểu và bất biến vào prompt.      | Prompt mơ hồ ("sửa test và implement solver").                      |
| **3. Không Tin mù quáng AI**            | Bắt Bẫy AI khi rà soát diff; chất vấn giả định AI trước khi apply.          | Apply code AI mà không đọc; ngạc nhiên khi test fail.               |
| **4. Tốc độ Đọc Code**                  | Ánh xạ nhanh điểm vào → logic lõi → test harness trong 10 phút.             | Không giải thích được hàm hiện có làm gì nếu không hỏi AI liên tục. |
| **5. Khám phá Bug & Trường hợp Biên**   | Xác định nguyên nhân gốc và chủ động test biên rỗng, trùng lặp hoặc quy mô. | Vá triệu chứng bằng nhánh `if` hacky thay vì sửa nguyên nhân gốc.   |
| **6. Kiểm thử trước khi Tuyên bố Xong** | Chạy test suite sau mỗi micro-change; thêm test regression mới.             | Tuyên bố "xong" ngay khi AI sinh code mà chưa chạy test.            |
| **7. Giải thích vì sao Giải pháp Đúng** | Trình bày rõ độ phức tạp, bất biến được bảo toàn và đánh đổi.               | Nói "AI viết thế và test pass."                                     |
