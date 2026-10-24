# E01 — Gilded Rose Inventory Bugfix & Conjured Decay Cap

[⬅️ Quay lại Danh mục Easy](README.md) · [🏠 Hub Chính](../../../README.md)

| Thuộc tính            | Chi tiết                                                                                                                         |
| :-------------------- | :------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**           | `E01`                                                                                                                            |
| **Mức độ Khó**        | 🟢 **Easy** (`30–45 phút` — Mức Junior / Mid)                                                                                    |
| **Task Archetype**    | Legacy Refactoring + Feature Extension                                                                                           |
| **GitHub Repo Nguồn** | [`emilybache/GildedRose-Refactoring-Kata`](https://github.com/emilybache/GildedRose-Refactoring-Kata)                            |
| **File Mục tiêu**     | `gilded_rose.py` & `tests/test_gilded_rose.py` _(hoặc `TypeScript/`, `go/`, `Java/`, `rust/`, `csharp.NUnit/`, `csharp.xUnit/`)_ |
| **Ngôn ngữ Hỗ trợ**   | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                               |
| **Bẫy AI Chính**      | Kiểm tra prefix `"Conjured"` làm hỏng `"Conjured Aged Brie"` & `"Conjured Sulfuras"` · `quality = 1` sau hết hạn xuống `-3`      |

---

## 1. Thiết lập Người phỏng vấn & Manifest Bug Gieo sẵn (Bảo mật)

(See English version for full confidential setup details.)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/GildedRose-Refactoring-Kata.git gilded-rose-interview
cd gilded-rose-interview/python # (or TypeScript / go / Java / rust / csharp.NUnit / csharp.xUnit)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Backstage Pass Post-Concert Quality Floor / Cap Off-by-One)**: Seed a bug in `gilded_rose.py` where `Backstage passes` with `sell_in == 5` (or `sell_in == 10`) uses `< 5` instead of `< 6`, or where post-concert quality drops by `1` instead of dropping to `0`.
2. **Commented Tests**: Add commented-out unit tests in `tests/test_gilded_rose.py` for `Backstage passes` boundary days (`sell_in = 10, 5, 0`), `"Conjured Mana Cake"`, `"Conjured Aged Brie"`, and `"Conjured Sulfuras, Hand of Ragnaros"`.

---

## 2. Hướng dẫn Ứng viên (Copy-Paste vào CoderPad / IDE)

> ### Chào mừng đến với Buổi phỏng vấn SWE Lập trình hỗ trợ AI của Bạn
>
> Bạn đang làm việc trên trình cập nhật chất lượng tồn kho cho quán trọ **Gilded Rose**. Bạn có thể dùng Trợ lý AI nhiều hay ít tùy thích.
>
> ### Điều Chúng tôi Cần Bạn làm
>
> Công việc cập nhật tồn kho hàng ngày theo dõi hai thuộc tính cho mỗi món:
>
> - `sell_in`: Số ngày còn lại để bán món.
> - `quality`: Giá trị của món (`0 <= quality <= 50` cho mọi món ngoại trừ `"Sulfuras"`).
>
> Hiện tại, team chúng tôi nhận thấy bug biên trong cách **Backstage passes** được cập nhật quanh các ngày ngưỡng concert (`10` ngày, `5` ngày và sau khi concert qua), và một vài test regression trong test suite đã bị comment tạm thời.
>
> Ngoài việc sửa bug đó, chúng tôi cần rollout hỗ trợ các món **`"Conjured"`** (mọi món có tên bắt đầu bằng `"Conjured "`):
>
> 1. **Standard Items**: `quality` giảm `1` trước khi hết hạn (`sell_in > 0`), và `2` mỗi ngày sau ngày bán (`sell_in <= 0`).
> 2. **`"Aged Brie"`**: _Tăng_ `quality` theo thời gian (`+1` khi `sell_in > 0`, `+2` khi `sell_in <= 0`), capped ở `50`.
> 3. **`"Sulfuras, Hand of Ragnaros"`**: Món huyền thoại; `sell_in` không bao giờ thay đổi và `quality` luôn `80`.
> 4. **`"Backstage passes to a TAFKAL80ETC concert"`**: `quality` tăng `+1` khi `sell_in > 10`, `+2` khi `6 <= sell_in <= 10`, `+3` khi `1 <= sell_in <= 5`, và xuống **`0`** sau concert (`sell_in <= 0`), luôn capped ở `50`.
> 5. **Quy tắc Modifier Mới `"Conjured"` (Prefix `"Conjured "`)**:
>    - Conjured thường (ví dụ `"Conjured Mana Cake"`) giảm `quality` **gấp đôi** standard (`-2` khi `sell_in > 0`, `-4` khi `sell_in <= 0`), floored ở `0`.
>    - `"Conjured Aged Brie"` tăng `quality` **gấp đôi** `"Aged Brie"` thường (`+2` khi `sell_in > 0`, `+4` khi `sell_in <= 0`), capped ở `50`.
>    - `"Conjured Sulfuras, Hand of Ragnaros"` vẫn huyền thoại (`sell_in` không đổi, `quality == 80`).
>    - Ràng buộc quan trọng: **Không** sửa định nghĩa lớp `Item` hay chữ ký thuộc tính `items`.
>
> Vui lòng khám phá codebase, bật lại các test bị comment, sửa defect hiện có, implement quy tắc `"Conjured"` sạch sẽ và đảm bảo các trường hợp biên (như `quality = 1` tại `sell_in = 0` hay `quality = 49` trên `"Conjured Aged Brie"`) được bao phủ bởi test.

---

## 3. Bẫy AI & Giải pháp Kỳ vọng (Bảo mật)

(See English version.)

## 4. Quy trình Prompt Divide-and-Conquer Tham khảo

(See English version.)

## 5. Rubric Chấm điểm HR & Người phỏng vấn (Cả 7 Tiêu chí)

(See English version.)
