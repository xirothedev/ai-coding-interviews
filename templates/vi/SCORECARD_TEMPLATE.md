# Phỏng vấn Lập trình hỗ trợ AI — Scorecard Ứng viên

| Metadata Phiên                 | Chi tiết                                                                         |
| :----------------------------- | :------------------------------------------------------------------------------- |
| **Tên Ứng viên / Nhân viên**   |                                                                                  |
| **Vai trò & Cấp Mục tiêu**     | `L3 (Junior)` / `L4 (Mid)` / `L5 (Senior)` / `L6+ (Staff/Principal)`             |
| **Case ID & Tiêu đề**          | ví dụ `M01 — Wordle Puzzle & Solver Engine` / `H01 — Async HTTP Connection Pool` |
| **Ngôn ngữ Lập trình Sử dụng** | `Python` / `TypeScript` / `Go` / `Java` / `Rust` / `C#`                          |
| **Công cụ AI Sử dụng**         | `CoderPad AI` / `Cursor` / `Claude Code` / `GitHub Copilot` / `ChatGPT`          |
| **Người phỏng vấn & Ngày**     |                                                                                  |
| **Khuyến nghị Tổng thể**       | `Strong No Hire (1)` / `No Hire (2)` / `Hire (3)` / `Strong Hire (4)`            |

---

## Phần 1: Cổng Hoàn thành Checkpoint

_Thanh qua tiêu chuẩn: Hoàn thành Checkpoint 1–3 sạch, cộng bảo vệ trường hợp biên ở Checkpoint 4 (3 đến 4 trong 4 checkpoint)._

| Checkpoint                                          | Trạng thái (`Pass` / `Partial` / `Fail`) | Thời gian | Ghi chú Người phỏng vấn                                    |
| :-------------------------------------------------- | :--------------------------------------: | :-------: | :--------------------------------------------------------- |
| **CP1: Khám phá Codebase & Chạy/Bỏ comment Test**   |                                          |  `~10m`   | Có đọc test & theo dõi luồng trước khi sửa không?          |
| **CP2: Chẩn đoán & Sửa Bug Có sẵn/Gieo sẵn**        |                                          |  `~15m`   | Sửa nguyên nhân gốc hay vá triệu chứng?                    |
| **CP3: Implement Tính năng Lõi / Mục tiêu Quy mô**  |                                          |  `~20m`   | Prompt tăng dần hay dump toàn bộ spec?                     |
| **CP4: Trường hợp Biên, Bẫy AI & Bảo vệ Giải pháp** |                                          |  `~15m`   | Bắt được Bẫy AI và giải thích vì sao code hoạt động không? |

---

## Phần 2: Scorecard 7 Tiêu chí Đánh giá (Thang 1–4)

### Thang điểm

- **1 — Blind Vibe-Coder (Strong No Hire)**: Copy-paste yêu cầu vào AI mù quáng, chấp nhận diff lớn mà không đọc, không giải thích được code hiện có hay sửa bug AI sinh ra.
- **2 — Phụ thuộc Quá mức / Phản ứng (No Hire)**: Dùng AI qua thử-sai prompting ("vẫn hỏng, sửa đi"), bỏ sót bug/bẫy tinh vi, thói quen xác minh yếu.
- **3 — Điều phối Viên AI Vững (Hire)**: Theo `Understand → Plan → Prompt → Review → Test`; phân rã bài toán sạch, kiểm toán diff, bắt trường hợp biên và sở hữu mọi dòng đã commit.
- **4 — Kỹ sư Bội số Lực lượng (Strong Hire)**: Tốc độ kiến trúc xuất sắc; dùng AI phẫu thuật để ánh xạ luồng và tăng tốc boilerplate trong khi chủ động chặn trước bẫy quy mô/concurrency và viết test nghiêm ngặt.

|   #   | Tiêu chí Đánh giá                                      | Điểm (1–4)  | Bằng chứng Quan sát (Prompt dùng, Diff bị từ chối, Test chạy)      |
| :---: | :----------------------------------------------------- | :---------: | :----------------------------------------------------------------- |
| **1** | **Phân rã Vấn đề** (_Divide & Conquer_)                |    `/ 4`    |                                                                    |
| **2** | **Chất lượng Ngữ cảnh Prompt**                         |    `/ 4`    |                                                                    |
| **3** | **Hoài nghi AI & Rà soát Diff** (_Không Tin mù quáng_) |    `/ 4`    |                                                                    |
| **4** | **Tốc độ Đọc Code**                                    |    `/ 4`    |                                                                    |
| **5** | **Khám phá Bug & Trường hợp Biên**                     |    `/ 4`    |                                                                    |
| **6** | **Xác minh & Kiểm thử trước khi Tuyên bố Xong**        |    `/ 4`    |                                                                    |
| **7** | **Giải thích vì sao Giải pháp Đúng**                   |    `/ 4`    |                                                                    |
|       | **ĐIỂM TRUNG BÌNH**                                    | **`/ 4.0`** | _(Thanh Mục tiêu: `>= 3.0` với không có `1` ở Tiêu chí #3 hay #6)_ |

---

## Phần 3: Red Flag Tức thì Quan sát (Đánh dấu mọi cái xảy ra)

- [ ] **Prompt Không đọc**: Paste hướng dẫn bài toán vào AI trước khi mở `src/` hoặc chạy test hiện có.
- [ ] **Chấp nhận Diff Mù**: Apply block code AI nhiều hàm mà không đọc từng dòng hay chất vấn giả định ẩn.
- [ ] **Prompt Thrashing ("Sửa đi" Loop)**: Paste raw stack trace lại vào AI 3+ lần mà không chẩn đoán nguyên nhân gốc.
- [ ] **Can thiệp Test**: Sửa hoặc xóa assertion unit test hợp lệ chỉ để làm test suite xanh.
- [ ] **Tuyên bố "Xong" chưa Xác minh**: Tuyên bố checkpoint hoàn thành trước khi chạy test suite hay kiểm tra điều kiện biên.
- [ ] **Mất Quyền sở hữu Code**: Không giải thích được vì sao một cấu trúc dữ liệu, điều kiện hay helper AI sinh ra là cần thiết.

---

## Phần 4: Tóm tắt Debrief Bằng văn bản

- **Điểm Mạnh Thể hiện**:
- **Khoảng trống / Rủi ro Xác định**:
- **Lý do Tuyển dụng / Leveling Cuối cùng**:
