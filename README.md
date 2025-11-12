# Go Forum 💬

A full-featured discussion forum built with **Go**, **SQLite**, and **vanilla JavaScript**. Features user authentication, multi-category posts, a like/dislike system, and comprehensive input validation.

![Go Version](https://img.shields.io/badge/Go-1.24.6-00ADD8?logo=go)
![SQLite](https://img.shields.io/badge/SQLite-3-003B57?logo=sqlite)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

### 🔐 Authentication & Security
- **User Registration** with bcrypt password hashing
- **Session-Based Authentication** (24-hour sessions)
- Single session per user enforcement
- CSRF-ready architecture
- **Strong Password Policy**:
  - 8-128 characters
  - At least one uppercase letter (A-Z)
  - At least one lowercase letter (a-z)
  - At least one digit (0-9)
  - At least one special character (!@#$%^&*)
  - **No spaces allowed** (enforced client & server-side)
- **Unicode Support** (emoji, Cyrillic, Arabic, Chinese, etc.)
- **Input Validation** (client-side & server-side synchronized)

### 📝 Post & Content Management
- Create posts with **multiple categories** (1-5 per post)
- Rich text content with Unicode support
- **View counter** for posts
- **Post Filtering**: All posts, My posts, Liked posts, By category
- Content preview with "Read more" functionality
- Character counters with real-time validation

### 💬 Interaction
- **Comment system** with like/dislike
- **Like/dislike posts** with toggle functionality
- Real-time character counters
- Instant validation feedback
- Singular/plural grammar handling ("1 comment" vs "2 comments")

### 🎨 User Experience (UX)
- Clean, **responsive design**
- Real-time form validation with character counters
- Styled error pages (400, 404, 405, 500)
- Empty state messages with helpful Call-to-Actions (CTAs)
- **Mobile-friendly** interface
- Consistent terminology throughout (Comments, not Replies)

## 🚀 Quick Start

### Prerequisites
- Go **1.24.6** or higher
- **SQLite3**
- **Docker** (optional, for containerized deployment)

### Installation

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd forum
```

2. **Install dependencies**
```bash
go mod download
```

3. **Run the server**
```bash
go run cmd/server/main.go
```

### Access the Forum
Open your browser and navigate to:

`http://localhost:8080`

### Default Admin Account

| Username | Password   |
|----------|------------|
| `admin`  | `admin123` |

**⚠️ Important:** Change the admin password after first login in production!

## 🐳 Docker Deployment

### Quick Start with Docker
```bash
# Build and run
make build
make run

# Access at http://localhost:8080

# Default admin account:
# Username: admin
# Password: admin123
```

### Docker Commands

| Command | Description |
|---------|-------------|
| `make build` | Build Docker image |
| `make run` | Start container (uses local database) |
| `make stop` | Stop and remove container |
| `make logs` | View container logs |
| `make shell` | Open shell in container |
| `make restart` | Restart container |
| `make status` | Show container status |
| `make db` | Access SQLite database |
| `make backup` | Backup database to ./backups/ |
| `make check-db` | Show database statistics |
| `make clean` | Remove container (keeps database) |
| `make clean-all` | Remove everything including database |
| `make download-db` | Download database from container |
| `make upload-db` | Upload local database to container |

### Testing Commands

| Command | Description |
|---------|-------------|
| `make test` | Run all test suites (master test runner) |
| `make test-validation` | Run input validation tests |
| `make test-password` | Run password policy tests |
| `make test-backend` | Run backend validation tests |
| `make test-required` | Run required fields tests |
| `make test-category` | Run category validation tests |
| `make test-sessions` | Run session management tests |
| `make test-forum` | Run forum integration tests |
| `make test-endpoints` | Run security & endpoint tests |
| `make test-comment` | Run comment route security tests |
| `make test-status` | Run HTTP status code tests |
| `make test-http` | Run HTTP method tests |
| `make test-templates` | Run template error tests |
| `make test-cleanup` | Clean up test users from database |

### Database Options

**Default behavior:** Uses local `forum.db` in project folder
- ✅ See database file on your computer
- ✅ Use SQLite tools directly
- ✅ Easy backup and restore
- ✅ Changes sync automatically

**Alternative:** Use Docker volume for isolated storage
```bash
make run-volume  # Creates fresh database in Docker volume
```

## 🛠️ Technology Stack

### Backend
- **Language**: Go 1.24.6
- **Database**: SQLite3 with WAL mode
- **Session Storage**: SQLite with UUID tokens
- **Password Hashing**: `bcrypt` (cost factor: 10)
- **Template Engine**: Go `html/template`
- **Timezone**: Asia/Almaty (configurable)

### Frontend
- HTML5 with semantic markup
- CSS3 with responsive design
- Vanilla JavaScript for client-side validation
- **No frameworks** - lightweight and fast
- Real-time input validation

### Libraries & Dependencies
- `github.com/google/uuid` v1.6.0 - UUID generation
- `github.com/mattn/go-sqlite3` v1.14.32 - SQLite driver
- `golang.org/x/crypto` v0.42.0 - bcrypt hashing

## 📁 Project Structure
```
forum/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go            # Configuration management
│   ├── database/
│   │   └── db.go                # Database initialization & migrations
│   ├── handlers/
│   │   ├── auth.go              # Registration, login, logout
│   │   ├── forum.go             # Posts, comments, categories
│   │   ├── likes.go             # Like/dislike functionality
│   │   └── errors.go            # Error page rendering
│   ├── middleware/
│   │   └── auth.go              # Authentication middleware
│   ├── models/
│   │   ├── user.go              # User model
│   │   ├── post.go              # Post model
│   │   └── category.go          # Category & Comment models
│   ├── services/
│   │   ├── user.go              # User business logic
│   │   ├── session.go           # Session management
│   │   └── likes.go             # Like/dislike logic
│   └── validation/
│       └── validation.go        # Input validation rules
├── web/
│   ├── static/
│   │   └── css/
│   │       └── style.css        # Application styles
│   └── templates/
│       ├── layout.html          # Main layout template
│       ├── home.html            # Homepage
│       ├── category.html        # Category view
│       ├── post.html            # Post detail view
│       ├── create_post.html     # Create post form
│       ├── register.html        # Registration form
│       ├── login.html           # Login form
│       └── error.html           # Error pages
├── scripts/
│   ├── docker/
│   │   └── docker.sh            # Docker helper scripts
│   ├── setup/
│   │   └── cleanup_test_users.sh # Test user cleanup
│   └── test/
│       ├── run_all_tests.sh     # Master test runner
│       ├── test_validation.sh   # Input validation tests
│       ├── test_password_validation.sh # Password policy tests
│       ├── test_sessions.sh     # Session management tests
│       ├── test_forum.sh        # Forum integration tests
│       ├── test_forum_endpoints.sh # Security tests
│       ├── test_comment_routes.sh # Comment security tests
│       ├── test_category.sh     # Category validation tests
│       ├── test_status_codes.sh # HTTP status code tests
│       ├── test_http_methods.sh # HTTP method tests
│       ├── test_backend_validation.sh # Backend validation tests
│       ├── test_post_required_fields.sh # Required fields tests
│       └── test_templates.sh    # Template error tests
├── Dockerfile                   # Docker configuration
├── Makefile                     # Build & deployment commands
├── go.mod                       # Go module definition
├── go.sum                       # Go dependencies checksum
├── forum.db                     # SQLite database (created on first run)
└── README.md                    # This file
```

## 🧪 Testing

### Comprehensive Test Suite

The application includes **12 comprehensive test suites** covering all aspects:

#### Core Test Suites

1. **Input Validation Tests** (`test_validation.sh`)
   - Username validation (length, characters, spaces)
   - Email validation (format, TLD, special cases)
   - Password validation (basic length checks)
   - Post/comment validation
   - Unicode character handling

2. **Password Policy Tests** (`test_password_validation.sh`)
   - Strong password requirements (30+ test cases)
   - Uppercase, lowercase, digit, special character validation
   - Space rejection enforcement
   - Password strength meter validation
   - Minimum/maximum length validation

3. **Backend Validation Tests** (`test_backend_validation.sh`)
   - Server-side validation enforcement
   - Post title/content length validation
   - Comment content validation
   - Category selection validation

4. **Required Fields Tests** (`test_post_required_fields.sh`)
   - Missing field rejection
   - Empty string validation
   - Whitespace-only field rejection
   - Category count validation (1-5)

5. **Category Validation Tests** (`test_category.sh`)
   - Category ID format validation
   - Invalid ID rejection (letters, negative, zero)
   - SQL injection prevention

6. **Session Management Tests** (`test_sessions.sh`)
   - Cookie creation and validation
   - Session expiration
   - Single session per user enforcement
   - Cookie security attributes
   - Logout session destruction

7. **Forum Integration Tests** (`test_forum.sh`)
   - Multi-user workflows
   - Post creation with multiple categories
   - Comment system
   - Like/dislike functionality
   - Post filtering (my posts, liked posts, categories)

8. **Security & Endpoint Tests** (`test_forum_endpoints.sh`)
   - Non-existent resource handling (404)
   - Authentication requirements (303 redirects)
   - Post/comment endpoint validation

9. **Comment Route Security** (`test_comment_routes.sh`)
   - Double slash protection
   - Missing comment ID validation
   - Invalid ID format rejection
   - HTTP method validation

10. **HTTP Status Code Tests** (`test_status_codes.sh`)
    - 400 Bad Request for invalid formats
    - 404 Not Found for missing resources
    - 405 Method Not Allowed
    - 303 See Other for redirects

11. **HTTP Method Tests** (`test_http_methods.sh`)
    - GET/POST method validation
    - Invalid method rejection (PUT, DELETE)
    - Method-based routing

12. **Template Error Tests** (`test_templates.sh`)
    - Missing template handling
    - 500 Internal Server Error pages
    - Template restoration

### Running Tests

```bash
# Run all tests (recommended)
make test
# or
./scripts/test/run_all_tests.sh

# Run individual test suites
make test-validation      # Input validation
make test-password        # Password policy
make test-backend         # Backend validation
make test-required        # Required fields
make test-category        # Category validation
make test-sessions        # Session management
make test-forum           # Forum features
make test-endpoints       # Security tests
make test-comment         # Comment route security
make test-status          # HTTP status codes
make test-http            # HTTP methods
make test-templates       # Template errors

# Run specific test directly
./scripts/test/test_validation.sh
./scripts/test/test_password_validation.sh
./scripts/test/test_backend_validation.sh
./scripts/test/test_post_required_fields.sh
./scripts/test/test_category.sh
./scripts/test/test_sessions.sh
./scripts/test/test_forum.sh
./scripts/test/test_forum_endpoints.sh
./scripts/test/test_comment_routes.sh
./scripts/test/test_status_codes.sh
./scripts/test/test_http_methods.sh
./scripts/test/test_templates.sh

# Clean up test users
make test-cleanup
```# Clean up test users
make test-cleanup
```

### Test Coverage

✅ **Authentication & Security**
- User registration with strong password policy
- Login/logout functionality
- Session management (creation, validation, expiration)
- Single session per user enforcement
- Password space rejection

✅ **Input Validation**
- All form fields (username, email, password, titles, content)
- Character length validation (synchronized client/server)
- Unicode character handling (emoji, Cyrillic, etc.)
- Whitespace-only field rejection
- Category selection validation

✅ **Forum Features**
- Post creation with multiple categories
- Comment system
- Like/dislike functionality (posts & comments)
- Post filtering (all, my posts, liked posts, by category)
- View counter functionality

✅ **Security & Error Handling**
- HTTP status codes (400, 404, 405, 500)
- Invalid ID format rejection
- SQL injection prevention
- Protected route authentication
- Double slash attack prevention
- Missing resource handling

✅ **HTTP Method Validation**
- GET/POST method enforcement
- Invalid method rejection (PUT, DELETE, PATCH)
- Method-based routing validation

✅ **Template System**
- Template error handling
- 500 error page rendering
- Missing template fallback

### Test Results Format

All tests provide clear, color-coded output:
- 🟢 **Green** - Test passed
- 🔴 **Red** - Test failed
- 🟡 **Yellow** - Info or partial pass

Example output:
```
=========================================
Password Validation Test Suite
=========================================
✓ PASS: Short username rejected (< 3 chars)
✓ PASS: Invalid email format rejected
✓ PASS: Password without uppercase rejected
✗ FAIL: Should reject space in password

Total Tests: 30
Passed: 29
Failed: 1
```

## 📊 Database Schema

### Tables
- **users**: User accounts with UUID, bcrypt passwords
- **sessions**: Active user sessions with expiration
- **categories**: Forum categories (General, Tech, Announcements, Help & Support, Off-Topic)
- **posts**: Forum posts with view counters
- **post_categories**: Many-to-many relationship (posts ↔ categories)
- **comments**: Post comments (internal name: `comments`, UI shows "Comments")
- **post_likes**: Post likes/dislikes with toggle support
- **comment_likes**: Comment likes/dislikes with toggle support

### Key Features
- **Foreign key constraints** enabled
- **WAL mode** for better concurrency
- **Optimized indexes** on:
  - User lookups (username, email)
  - Post queries (user_id, created_at)
  - Session validation (token, expiration)
  - Category filtering
  - Like/dislike counts

## 🔒 Security Features

### Implemented
- ✅ **Strong Password Policy** (8-128 chars, mixed case, digits, special chars, no spaces)
- ✅ Password hashing with bcrypt (cost factor: 10)
- ✅ Session-based authentication with secure tokens
- ✅ Single session per user enforcement
- ✅ SQL injection prevention (prepared statements)
- ✅ XSS prevention (template auto-escaping)
- ✅ Input validation (client + server synchronized)
- ✅ Session expiration (24 hours)
- ✅ HTTPOnly cookies
- ✅ UUID for user identification
- ✅ HTTP method validation (405 for invalid methods)
- ✅ ID format validation (400 for invalid formats)
- ✅ Resource existence validation (404 for missing)
- ✅ Double slash attack prevention
- ✅ Directory traversal prevention (static files)
- ✅ File type whitelist (static files)

### Recommended for Production
- HTTPS/TLS encryption
- CSRF token protection
- Rate limiting (login attempts, post creation)
- Content Security Policy (CSP) headers
- Secure cookie flags (Secure, SameSite=Strict)
- Input sanitization for HTML content
- Account lockout after failed login attempts
- Production database (PostgreSQL/MySQL for high traffic)
- Logging and monitoring
- Regular security audits

## 📝 Input Validation Rules

| Field           | Length              | Requirements                              | Notes                              |
|-----------------|---------------------|------------------------------------------|------------------------------------|
| Username        | 3-50 chars          | Letters, numbers, underscore, hyphen     | Pattern: `[a-zA-Z0-9_-]+`         |
| Email           | Max 100 chars       | Valid email format with TLD              | e.g., `user@example.com`          |
| Password        | 8-128 chars         | **Strong policy enforced**               | See password requirements below   |
| Post Title      | 3-255 chars         | Unicode, emoji supported                 | No leading/trailing spaces        |
| Post Content    | 10-10,000 chars     | Unicode, emoji, line breaks              | No leading/trailing spaces        |
| Comment Content | 10-5,000 chars      | Unicode, emoji, line breaks              | No leading/trailing spaces        |
| Categories      | 1-5 selection       | Positive integers only                   | Required, validated server-side   |

### Strong Password Requirements

✅ **Must contain:**
- At least 8 characters
- Maximum 128 characters
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one digit (0-9)
- At least one special character: `!@#$%^&*()-_=+[]{}|;:',.<>?/~`
- **No spaces allowed** (enforced both client and server-side)

❌ **Examples of invalid passwords:**
- `password` - no uppercase, no digit, no special char
- `Password` - no digit, no special char
- `Password1` - no special char
- `Pass 123!` - contains space ❌
- `Pas1!` - too short (< 8 chars)

✅ **Examples of valid passwords:**
- `Password123!`
- `MyP@ss2024`
- `Str0ng#Pass$`
- `Secure_Pass1`
- `Valid-Pass7`

### Validation Synchronization
Client-side and server-side validation are **perfectly synchronized**:
- **Server**: `utf8.RuneCountInString()` (Go)
- **Client**: `Array.from(str).length` (JavaScript)

This correctly counts multi-byte characters like emojis:
- `"hello"` = 5 characters
- `"🔒💪"` = 2 characters (not 4)
- `"Привет"` = 6 characters
- `"password 123"` = ❌ Rejected (contains space)

## 🚧 Known Limitations

### Not Yet Implemented
- No email verification (accounts active immediately)
- No password reset functionality (admin must reset)
- No image upload (text-only posts and comments)
- No pagination (may be slow with 1000+ posts)
- No search functionality
- No user profile pages
- No edit/delete for posts or comments
- No post sorting options (newest, most liked, etc.)
- No admin moderation panel
- No rate limiting (vulnerable to spam)
- No "Remember Me" functionality

### Technical Limitations
- SQLite not suitable for high-concurrency production (100+ simultaneous users)
- No real-time notifications
- No API for mobile apps
- Session-only authentication

## 🗺️ Roadmap

### Phase 1: Core Improvements (Priority)
- [ ] **Pagination** (20 posts per page)
- [ ] **Edit & Delete** own posts/comments
- [ ] **Search functionality** (title, content, username)
- [ ] **User profile pages** (view user's posts & comments)
- [ ] **Post sorting** (newest, most liked, most viewed)

### Phase 2: User Experience
- [ ] **Markdown support** in posts/comments
- [ ] **Dark mode** toggle
- [ ] **Notifications** (replies, likes)
- [ ] **Email verification** on registration
- [ ] **Password reset** via email

### Phase 3: Security & Moderation
- [ ] **Rate limiting** (prevent spam)
- [ ] **Admin panel** (user management, moderation)
- [ ] **Report system** (flag inappropriate content)
- [ ] **CSRF token protection**
- [ ] **Account lockout** (failed login attempts)

### Phase 4: Advanced Features
- [ ] **Image uploads** (posts & comments)
- [ ] **Tags system** (alternative to categories)
- [ ] **Bookmarks/Favorites** (save posts)
- [ ] **Real-time features** (WebSocket notifications)
- [ ] **RESTful API** for mobile apps
- [ ] **Social login** (Google, GitHub)

## 🤝 Contributing

Contributions are welcome!

### How to Contribute
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Go conventions (`gofmt`, `golint`)
- Write descriptive commit messages
- Add tests for new features
- Update documentation (README, comments)
- Ensure all tests pass before submitting

### Testing Your Changes
```bash
# Run all tests
make test
# or
./scripts/test/run_all_tests.sh

# Run specific test suite
make test-validation          # or ./scripts/test/test_validation.sh
make test-password            # or ./scripts/test/test_password_validation.sh
make test-backend             # or ./scripts/test/test_backend_validation.sh
make test-sessions            # or ./scripts/test/test_sessions.sh
make test-forum               # or ./scripts/test/test_forum.sh

# Test with Docker
make build
make run
make logs
```

## 👨‍💻 Author

- **Name**: Rauan

## 🙏 Acknowledgments

- **Go community** for excellent documentation and tools
- **SQLite** for a reliable embedded database
- **bcrypt** for secure password hashing
- **Everyone who tested and provided feedback**

Special thanks to all contributors and testers who helped improve this project!

---

**Built with ❤️ using Go**

*Last updated: November 2025*