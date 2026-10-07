# Báo Cáo Lab Day 21 - CI/CD cho AI Systems

| | |
|---|---|
| Họ và tên | Phạm Thành Sơn |
| MSSV | 2A202602794 |
| Lớp / Khóa | K4 |
| Repo GitHub | https://github.com/holyspirit2207/K4-L3L4-Track2-Day21-PhamThanhSon-2A202602794-CI-CD-for-AI-Systems |
| Ngày nộp | 07/10/2026 |

---

## 1. Bộ Siêu Tham Số Đã Chọn và Lý Do

| Lần chạy | n_estimators | learning_rate | max_depth | f1_score | accuracy |
|---|---|---|---|---|---|
| 1 | 100 | 0.1 | 3 | 0.7109 | 0.8780 |
| 2 | 50 | 0.05 | 2 | 0.6051 | 0.8460 |
| 3 | 200 | 0.1 | 5 | 0.7149 | 0.8740 |

**Bộ siêu tham số đã chọn:** `n_estimators=200`, `learning_rate=0.1`, `max_depth=5`.

**Lý do:** Lần chạy 3 đạt F1 cao nhất 0.7149 và vượt ngưỡng 0.65, dù accuracy 0.8740 thấp hơn mức 0.8780 của lần 1. Accuracy cao nhất vì thế không đồng nghĩa nhận diện lớp dương tốt nhất. Cấu hình 50 cây, learning rate 0.05 và độ sâu 2 học chậm, năng lực biểu diễn thấp nên F1 chỉ đạt 0.6051. Tăng lên 200 cây và độ sâu 5 tạo thêm vòng sửa sai và học được tương tác phức tạp hơn. Đổi lại, thời gian huấn luyện và nguy cơ overfit tăng, nhưng kết quả holdout vẫn tốt nhất trong ba lần chạy.

---

## 2. Vì Sao Ngưỡng Chất Lượng Đặt Trên F1 Chứ Không Phải Accuracy

Lớp thu nhập trên 50K chỉ chiếm 24,8%, còn lớp âm chiếm 75,2%. Mô hình luôn đoán “thu nhập thấp” vẫn đạt accuracy khoảng 75,2% dù không phát hiện mẫu dương nào, nên accuracy dễ gây hiểu nhầm. F1 kết hợp precision và recall, chỉ cao khi mô hình vừa hạn chế dự đoán dương sai vừa tìm được nhiều mẫu dương thật. Mã nguồn dùng `f1_score(y_eval, preds)` để đo riêng nhãn 1. Không dùng `average="weighted"` vì lớp âm đông hơn sẽ chi phối kết quả; không dùng `average="macro"` vì quality gate cần đánh giá riêng hiệu quả trên lớp dương.

---

## 3. Khó Khăn Gặp Phải và Cách Giải Quyết

| Khó khăn | Nguyên nhân | Cách giải quyết |
|---|---|---|
| Không cài được `scikit-learn` | `.venv` dùng Python 3.14, không có wheel phù hợp. | Tạo lại `.venv` bằng Python 3.11.9. |
| MLflow không mở SQLite | MLflow 2.13.0 xung đột SQLAlchemy 2.1.3. | Pin `sqlalchemy==2.0.36` và chạy lại test. |
| Mã nguồn phụ thuộc GCP | DVC, API và workflow dùng Google Storage. | Chuyển sang S3, `boto3`, OIDC và IAM role. |

---

## 4. So Sánh Bước 2 và Bước 3

| | f1_score | accuracy |
|---|---|---|
| Bước 2 (chỉ `train_batch1`) | 0.7149 | 0.8740 |
| Bước 3 (thêm `train_batch2`) | 0.7354 | 0.8820 |

**Nhận xét:** Khi tăng từ 22.361 lên 44.722 mẫu cùng phân phối, F1 tăng 0.0205 và accuracy tăng 0.0080. Cải thiện không lớn vì batch mới không mang phân phối khác, nhưng giúp mô hình ước lượng lớp dương ổn định hơn.
