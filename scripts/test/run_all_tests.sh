#!/bin/bash

# Master Test Runner for Forum Application
# Runs all test suites and provides comprehensive report

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
CONTINUE_ON_FAILURE=true  # Set to false to stop on first failure
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_DIR="test_logs"
REPORT_FILE="$LOG_DIR/test_report_${TIMESTAMP}.txt"

# Create log directory
mkdir -p "$LOG_DIR"

# Test results tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${CYAN}$1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to run a test suite
run_test_suite() {
    local script_name=$1
    local suite_name=$2
    local script_path="$SCRIPT_DIR/$script_name"
    local log_file="$LOG_DIR/${script_name}_${TIMESTAMP}.log"
    
    ((TOTAL_SUITES++))
    
    echo -e "${YELLOW}▶ Running: ${NC}${suite_name}..."
    echo ""
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}✗ SKIPPED${NC}: Script not found - $script_name"
        echo -e "${YELLOW}  Expected location: $script_path${NC}"
        ((SKIPPED_SUITES++))
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo -e "${YELLOW}⚠ Making script executable: $script_name${NC}"
        chmod +x "$script_path"
    fi
    
    # Run the test suite and capture output
    if "$script_path" > "$log_file" 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}: $suite_name"
        ((PASSED_SUITES++))
        
        # Show summary from log
        if grep -q "Passed:" "$log_file" 2>/dev/null; then
            tail -n 5 "$log_file" | grep "Passed:" | head -n 1
        elif grep -q "✓ PASS" "$log_file" 2>/dev/null; then
            echo "  $(grep -c "✓ PASS" "$log_file") tests passed"
        fi
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}: $suite_name"
        ((FAILED_SUITES++))
        
        # Show relevant error lines
        echo -e "${RED}Last 10 lines of output:${NC}"
        tail -n 10 "$log_file"
        
        if [ "$CONTINUE_ON_FAILURE" = false ]; then
            echo ""
            echo -e "${RED}Stopping due to test failure.${NC}"
            echo -e "${YELLOW}Check log: $log_file${NC}"
            exit 1
        fi
        return 1
    fi
}

# Function to check server status
check_server() {
    # Clean up old test data
    echo -e "${YELLOW}Cleaning up old test data...${NC}"
    if [ -f "forum.db" ]; then
        sqlite3 forum.db "DELETE FROM sessions WHERE user_id IN (SELECT id FROM users WHERE username LIKE 'testuser%' OR username LIKE 'validuser%' OR username LIKE 'pwtest%' OR username LIKE 'methodtest%' OR username LIKE 'reqtest%' OR username LIKE 'cattest%' OR username LIKE 'sessiontest%');" 2>/dev/null || true
        sqlite3 forum.db "DELETE FROM users WHERE username LIKE 'testuser%' OR username LIKE 'validuser%' OR username LIKE 'pwtest%' OR username LIKE 'methodtest%' OR username LIKE 'reqtest%' OR username LIKE 'cattest%' OR username LIKE 'sessiontest%';" 2>/dev/null || true
        echo -e "${GREEN}✓ Test data cleaned${NC}"
    else
        echo -e "${YELLOW}⚠ Database not found, skipping cleanup${NC}"
    fi
    echo ""

    echo -e "${YELLOW}Checking if server is running...${NC}"
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080" | grep -q "200"; then
        echo -e "${GREEN}✓ Server is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Server is not responding${NC}"
        echo -e "${YELLOW}Please start the server first:${NC}"
        echo "  go run cmd/server/main.go"
        echo "  or"
        echo "  make run"
        exit 1
    fi
}

# Function to generate final report
generate_report() {
    local duration=$1
    
    print_header "TEST EXECUTION SUMMARY"
    
    echo "Timestamp: $(date)"
    echo "Duration: ${duration}s"
    echo ""
    echo "Test Suites:"
    echo "  Total:   $TOTAL_SUITES"
    echo -e "  ${GREEN}Passed:  $PASSED_SUITES${NC}"
    echo -e "  ${RED}Failed:  $FAILED_SUITES${NC}"
    echo -e "  ${YELLOW}Skipped: $SKIPPED_SUITES${NC}"
    echo ""
    
    if [ $FAILED_SUITES -eq 0 ] && [ $SKIPPED_SUITES -eq 0 ]; then
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                        ║${NC}"
        echo -e "${GREEN}║     ✓ ALL TESTS PASSED! 🎉            ║${NC}"
        echo -e "${GREEN}║                                        ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo ""
        return 0
    elif [ $FAILED_SUITES -eq 0 ]; then
        echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠ Tests Passed (with skipped tests) ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║         ✗ TESTS FAILED ❌              ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Check detailed logs in: $LOG_DIR${NC}"
        return 1
    fi
}

# Main execution
main() {
    # Start timer
    START_TIME=$(date +%s)
    
    # Print banner
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║           Forum Application - Test Suite Runner               ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check server
    check_server
    echo ""
    
    # ========================================
    # Run all test suites
    # ========================================
    
    # Core validation tests
    print_header "1. Input Validation Tests"
    run_test_suite "test_validation.sh" "Input Validation Suite"
    
    # Password-specific validation
    print_header "2. Password Policy Tests"
    run_test_suite "test_password_validation.sh" "Password Security Suite"
    
    # Backend validation
    print_header "3. Backend Validation Tests"
    run_test_suite "test_backend_validation.sh" "Backend Validation Suite"
    
    # Required fields validation
    print_header "4. Required Fields Tests"
    run_test_suite "test_post_required_fields.sh" "POST Required Fields Suite"
    
    # Category validation
    print_header "5. Category Validation Tests"
    run_test_suite "test_category.sh" "Category ID Validation Suite"
    
    # Session management
    print_header "6. Session & Cookie Tests"
    run_test_suite "test_sessions.sh" "Session Management Suite"
    
    # Forum integration
    print_header "7. Forum Integration Tests"
    run_test_suite "test_forum.sh" "Forum Features Suite"
    
    # Security tests
    print_header "8. Security & Endpoint Tests"
    run_test_suite "test_forum_endpoints.sh" "Security Testing Suite"
    
    # Comment route security
    print_header "9. Comment Route Security Tests"
    run_test_suite "test_comment_routes.sh" "Comment Security Suite"
    
    # HTTP status codes
    print_header "10. HTTP Status Code Tests"
    run_test_suite "test_status_codes.sh" "Status Code Validation Suite"
    
    # HTTP methods
    print_header "11. HTTP Method Validation Tests"
    run_test_suite "test_http_methods.sh" "HTTP Method Suite"
    
    # Template tests
    print_header "12. Template Error Handling Tests"
    run_test_suite "test_templates.sh" "Template Testing Suite"
    
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Generate final report
    generate_report "$DURATION"
    
    # Save report to file
    generate_report "$DURATION" > "$REPORT_FILE"
    
    echo ""
    echo -e "${CYAN}Full report saved to: $REPORT_FILE${NC}"
    echo -e "${CYAN}Individual logs available in: $LOG_DIR/${NC}"
    echo ""
    
    # Exit with appropriate code
    if [ $FAILED_SUITES -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Parse command line arguments
CONTINUE_ON_FAILURE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --stop-on-failure)
            CONTINUE_ON_FAILURE=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --stop-on-failure    Stop execution on first test failure"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Example:"
            echo "  $0                        # Run all tests"
            echo "  $0 --stop-on-failure      # Stop on first failure"
            echo ""
            echo "Test Suites:"
            echo "  1.  Input Validation"
            echo "  2.  Password Policy"
            echo "  3.  Backend Validation"
            echo "  4.  Required Fields"
            echo "  5.  Category Validation"
            echo "  6.  Session Management"
            echo "  7.  Forum Integration"
            echo "  8.  Security & Endpoints"
            echo "  9.  Comment Route Security"
            echo "  10. HTTP Status Codes"
            echo "  11. HTTP Methods"
            echo "  12. Template Error Handling"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main
main