# Command Detection (language-agnostic)

Bảng tra lệnh test/lint/build của repo khi `.aitoolkit/project.yaml` KHÔNG khai báo (project-profile §4, bước 2 "tự dò"). Nhận diện qua marker file ở gốc repo. Nếu nhiều marker cùng tồn tại (monorepo/đa ngôn ngữ), ưu tiên marker gần thư mục có file vừa đổi nhất; nếu vẫn mơ hồ → BLOCKED, hỏi gate.

| Marker file | Hệ sinh thái | test_cmd (mặc định) | lint_cmd | build_cmd |
|---|---|---|---|---|
| `pubspec.yaml` | Dart/Flutter | `flutter test` (app) / `dart test` (package) | `flutter analyze` / `dart analyze` | `flutter build <target>` / `dart compile` |
| `package.json` | Node/JS/TS | script `test` → `<pm> test` | script `lint` | script `build` |
| `Cargo.toml` | Rust | `cargo test` | `cargo clippy` | `cargo build` |
| `go.mod` | Go | `go test ./...` | `go vet ./...` | `go build ./...` |
| `pom.xml` | Java (Maven) | `mvn test` | `mvn -q verify` | `mvn package` |
| `build.gradle`(`.kts`) | Java/Kotlin (Gradle) | `./gradlew test` | `./gradlew check` | `./gradlew build` |
| `pyproject.toml` / `setup.py` | Python | `pytest` (hoặc `python -m pytest`) | `ruff check` / `flake8` | `python -m build` |
| `*.csproj` / `*.sln` | .NET | `dotnet test` | `dotnet format --verify-no-changes` | `dotnet build` |
| `Gemfile` | Ruby | `bundle exec rspec` / `rake test` | `bundle exec rubocop` | — |
| `composer.json` | PHP | `composer test` / `vendor/bin/phpunit` | `vendor/bin/phpcs` | — |
| `CMakeLists.txt` / `Makefile` | C/C++ | `ctest` / `make test` | — | `cmake --build` / `make` |

## Node package manager (`<pm>`)

Suy ra từ lockfile: `pnpm-lock.yaml`→`pnpm`, `yarn.lock`→`yarn`, `bun.lockb`→`bun`, còn lại→`npm`. Chạy script khai báo trong `package.json` (`test`/`lint`/`build`) thay vì đoán runner.

## Quy tắc

- **Không có marker khớp**, script không tồn tại, **hoặc lệnh cần tham số không suy ra được** (vd `flutter build <target>` không rõ target) → **BLOCKED**, ghi phán đoán vào report, để gate người dùng cung cấp lệnh. KHÔNG bịa.
- Lệnh nào đã dùng thực tế phải ghi verbatim vào `verification-report.md` (mục "Lệnh đã chạy") kèm nguồn = "tự dò".
- Bảng này chỉ là mặc định; `.aitoolkit/project.yaml` luôn thắng khi có.
