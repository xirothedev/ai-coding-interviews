# E03 — Theatrical Players Statement Formatter & HTML Loyalty Credits

[⬅️ Quay lại Danh mục Easy](README.md) · [🏠 Hub Chính](../../../README.md)

> 🌐 Ngôn ngữ: <a href="E03-theatrical-players">English</a> · **Tiếng Việt**

| Thuộc tính            | Chi tiết                                                                                                                                                                    |
| :-------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**           | `E03`                                                                                                                                                                       |
| **Mức độ Khó**        | 🟢 **Easy** (`30–45 phút` — Mức Junior / Mid)                                                                                                                               |
| **Task Archetype**    | System Component Integration & Refactoring                                                                                                                                  |
| **GitHub Repo Nguồn** | [`emilybache/Theatrical-Players-Refactoring-Kata`](https://github.com/emilybache/Theatrical-Players-Refactoring-Kata)                                                       |
| **File Mục tiêu**     | `statement.py` & `tests/test_statement.py` _(hoặc `typescript/`, `go/`, `java/`, `rust/`, `csharp/`)_                                                                       |
| **Ngôn ngữ Hỗ trợ**   | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                                                                          |
| **Bẫy AI Chính**      | Nhân đôi công thức giá giữa `statement()` và `html_statement()` · Vòng lặp một lượt không phát hiện bonus repertoire cross-play khi `"tragedy"` xuất hiện _sau_ `"history"` |

---

## 1. Thiết lập Người phỏng vấn & Manifest Bug Gieo sẵn (Bảo mật)

(See English version.)

## 2. Hướng dẫn Ứng viên (Copy-Paste vào CoderPad / IDE)

> ### Chào mừng đến với Buổi phỏng vấn SWE Lập trình hỗ trợ AI của Bạn
>
> Bạn đang làm việc trên trình tạo hóa đơn statement cho một công ty sân khấu. Bạn có toàn quyền truy cập Trợ lý AI và unit test suite.
>
> ### Điều Chúng tôi Cần Bạn làm
>
> 1. **Sửa Bug Biên Phụ phí Comedy**:
>    - Với vở `"comedy"`, chi phí cơ bản là `$300.00` (`30000` cents) cộng `$3.00` (`300` cents) mỗi khán giả. Chỉ khi khán giả **nghiêm ngặt lớn hơn `20`** (`audience > 20`) mới thêm phụ phí `$100.00` (`10000` cents) cộng `$5.00` (`500` cents) mỗi khán giả trên `20`.
>    - Hiện tại, khán giả đúng `20` người bị tính quá.
> 2. **Hỗ trợ vở `"history"` & Bonus Repertoire Cross-Play**:
>    - Chi phí cơ bản `"history"`: `$350.00` (`35000` cents). Nếu `audience > 25`, thêm `$15.00` (`1500` cents) cho mỗi khán giả trên `25`.
>    - Volume credits cơ bản cho `"history"`: `max(audience - 25, 0) + floor(audience / 10)`.
>    - **Bonus Repertoire Cross-Play**: Nếu hóa đơn chứa **ít nhất một vở `"tragedy"` VÀ ít nhất một vở `"history"`** (bất kể xuất hiện trước trong danh sách performance), mọi performance `"history"` trên hóa đơn đó kiếm **gấp đôi (`2x`)** volume credits.
> 3. **Thêm Trình render Statement HTML**:
>    - Implement hàm statement HTML trả về biểu diễn HTML với đúng cùng các con số như plain-text `statement(invoice, plays)`, refactor sạch để công thức giá và credit không bao giờ bị nhân đôi giữa hai định dạng output.
>
> Vui lòng khám phá codebase, bật lại các test bị tắt trong test suite, sửa bug biên, implement vở `"history"` và `html_statement`, và xác minh bonus repertoire hoạt động bất kể thứ tự performance.

---

## 3. Bẫy AI & Giải pháp Kỳ vọng (Bảo mật)

(See English version.)

## 4. Quy trình Prompt Divide-and-Conquer Tham khảo

(See English version.)

## 5. Rubric Chấm điểm HR & Người phỏng vấn (Cả 7 Tiêu chí)

(See English version.)
