# E02 — Supermarket Receipt Discount Stacking & Bundle Rounding

[⬅️ Quay lại Danh mục Easy](README.md) · [🏠 Hub Chính](../../../README.md)

> 🌐 Ngôn ngữ: <a href="E02-supermarket-receipt">English</a> · **Tiếng Việt**

| Thuộc tính            | Chi tiết                                                                                                                                         |
| :-------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**           | `E02`                                                                                                                                            |
| **Mức độ Khó**        | 🟢 **Easy** (`30–45 phút` — Mức Junior / Mid)                                                                                                    |
| **Task Archetype**    | Bugfix + Feature Extension                                                                                                                       |
| **GitHub Repo Nguồn** | [`emilybache/SupermarketReceipt-Refactoring-Kata`](https://github.com/emilybache/SupermarketReceipt-Refactoring-Kata)                            |
| **File Mục tiêu**     | `shopping_cart.py`, `teller.py`, `receipt.py`, `model_objects.py`, `tests/test_supermarket.py` _(hoặc `typescript/`, `go/`, `java/`, `csharp/`)_ |
| **Ngôn ngữ Hỗ trợ**   | `Python`, `TypeScript`, `Go`, `Java`, `C#`                                                                                                       |
| **Bẫy AI Chính**      | Bug phần dư bundle (`7` món trên `5-for-X`) · Đánh giá ngưỡng coupon so với tổng gross trước bundle thay vì net · Trôi số thực                   |

---

## 1. Thiết lập Người phỏng vấn & Manifest Bug Gieo sẵn (Bảo mật)

(See English version for confidential setup details.)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/SupermarketReceipt-Refactoring-Kata.git supermarket-interview
cd supermarket-interview/python # (or typescript / go / java / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

(See English version.)

---

## 2. Hướng dẫn Ứng viên (Copy-Paste vào CoderPad / IDE)

> ### Chào mừng đến với Buổi phỏng vấn SWE Lập trình hỗ trợ AI của Bạn
>
> Bạn đang làm việc trên engine tính toán hóa đơn và thanh toán siêu thị. Bạn có toàn quyền truy cập Trợ lý AI và unit test suite.
>
> ### Điều Chúng tôi Cần Bạn làm
>
> 1. **Sửa Bug Overcharge Bundle Nhiều Lô**:
>    - Quản lý cửa hàng báo cáo khách mua nhiều bundle hoặc số lượng lẻ trên offer bundle (như `2-for-$A` hoặc `5-for-$A`, có thể quét qua nhiều lần thêm vào giỏ riêng biệt) bị tính tổng sai.
>    - Với tổng số lượng `Q` của một sản phẩm trên offer `N-for-$A` (giá đơn vị `P`): số bundle đầy đủ là `int(Q) // N` và các đơn vị lẻ còn lại là `Q - (bundles * N)`. Chi phí ròng cho sản phẩm đó phải bằng `bundles * A + remainder * P`.
> 2. **Thêm Coupon Trung thành Tối thiểu Theo Giỏ**:
>    - Chúng tôi muốn hỗ trợ coupon trung thành theo giỏ định nghĩa bởi `(threshold_amount, discount_amount)`:
>      - `threshold_amount` **phải được đánh giá so với subtotal giỏ ròng SAU KHI tất cả special offers cấp sản phẩm (`ThreeForTwo`, `TwoForAmount`, `FiveForAmount`, `TenPercentDiscount`) đã được khấu trừ**—không bao giờ so với subtotal gross trước giảm giá.
>      - Ví dụ, nếu tổng món gross là `$52.00` và bundle discounts trừ `$5.00`, subtotal ròng là `$47.00`, nên coupon `"$10 off $50+"` **không** áp dụng (`$47.00 < $50.00`).
>      - Đảm bảo trôi biểu diễn số thực (như `3 * 19.99 - 9.97` đánh giá thành `49.99999999999999`) không chặn một giỏ ròng đúng `$50.00`, và đảm bảo tổng hóa đơn cuối cùng làm tròn 2 chữ số thập phân và không bao giờ xuống dưới `0.00`.
>
> Vui lòng khám phá codebase, bật lại các test bị comment trong test suite, sửa bug bundle pricing, implement quy tắc loyalty coupon và thêm test bao phủ bundle quét nhiều lần và biên ngưỡng chính xác.

---

## 3. Bẫy AI & Giải pháp Kỳ vọng (Bảo mật)

(See English version.)

## 4. Quy trình Prompt Divide-and-Conquer Tham khảo

(See English version.)

## 5. Rubric Chấm điểm HR & Người phỏng vấn (Cả 7 Tiêu chí)

(See English version.)
