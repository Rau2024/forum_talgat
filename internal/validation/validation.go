package validation

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Email regex pattern - requires TLD (like .com, .org, etc.)
var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)

// Dangerous Unicode ranges that can break UI
var dangerousUnicodeRanges = []struct {
	start, end rune
	name       string
}{
	{0x0300, 0x036F, "Combining Diacritical Marks"},
	{0x1AB0, 0x1AFF, "Combining Diacritical Marks Extended"},
	{0x1DC0, 0x1DFF, "Combining Diacritical Marks Supplement"},
	{0x20D0, 0x20FF, "Combining Diacritical Marks for Symbols"},
	{0xFE20, 0xFE2F, "Combining Half Marks"},
	{0x200B, 0x200D, "Zero Width Characters"},
	{0x2060, 0x2064, "Word Joiner and Invisible Characters"},
	{0xFEFF, 0xFEFF, "Byte Order Mark"},
}

// Control characters that should be blocked
var controlCharRanges = []struct {
	start, end rune
}{
	{0x0000, 0x0008}, // C0 controls (NUL to BS) - excludes TAB
	{0x0B, 0x0C},     // VT and FF - excludes LF and CR
	{0x0E, 0x1F},     // SO to US - after CR
	{0x007F, 0x009F}, // Delete + C1 controls
}

// CleanText removes dangerous Unicode characters and excessive combining marks
// NOTE: Does NOT trim spaces - that should be done explicitly after validation
func CleanText(input string) string {
	if input == "" {
		return input
	}

	var cleaned strings.Builder
	combiningCount := 0
	maxCombining := 2 // Allow max 2 combining characters per base character

	for _, r := range input {
		// Skip control characters
		if isControlChar(r) {
			continue
		}

		// Check if it's a combining character
		if isCombiningChar(r) {
			combiningCount++
			// Allow only limited combining characters
			if combiningCount <= maxCombining {
				cleaned.WriteRune(r)
			}
			// Skip excessive combining chars (zalgo prevention)
			continue
		}

		// Reset combining count for non-combining characters
		combiningCount = 0

		// Skip other dangerous Unicode
		if isDangerousUnicode(r) {
			continue
		}

		// Keep normal characters (including spaces!)
		cleaned.WriteRune(r)
	}

	// ✅ FIXED: Return without trimming - let validation functions handle spaces explicitly
	return cleaned.String()
}

// isControlChar checks if character is a control character
func isControlChar(r rune) bool {
	for _, rang := range controlCharRanges {
		if r >= rang.start && r <= rang.end {
			return true
		}
	}
	return false
}

// isCombiningChar checks if character is a combining character
func isCombiningChar(r rune) bool {
	// Check Unicode categories for combining marks
	return unicode.In(r, unicode.Mn, unicode.Mc, unicode.Me)
}

// isDangerousUnicode checks if character is in dangerous Unicode ranges
func isDangerousUnicode(r rune) bool {
	for _, rang := range dangerousUnicodeRanges {
		if r >= rang.start && r <= rang.end {
			return true
		}
	}
	return false
}

// ValidateTextSafety checks for dangerous Unicode patterns
func ValidateTextSafety(input string) (bool, string) {
	if input == "" {
		return true, ""
	}

	// Check for excessive combining characters (zalgo detection)
	combiningCount := 0
	maxConsecutiveCombining := 5

	for _, r := range input {
		if isCombiningChar(r) {
			combiningCount++
			if combiningCount > maxConsecutiveCombining {
				return false, "Text contains excessive special characters that may break display"
			}
		} else {
			combiningCount = 0
		}
	}

	// Check for suspicious patterns
	if strings.Count(input, "í") > 10 || strings.Count(input, "ì") > 10 {
		return false, "Text contains suspicious character patterns"
	}

	// Check for zero-width characters
	if strings.Contains(input, "\u200B") || strings.Contains(input, "\u200C") || strings.Contains(input, "\u200D") {
		return false, "Text contains invisible characters"
	}

	return true, ""
}

// ValidateUsername checks if username is valid and safe
func ValidateUsername(username string) (bool, string) {
	// Clean dangerous Unicode only (preserves spaces)
	cleaned := CleanText(username)

	// ✅ NEW: Check for ANY spaces (username shouldn't have spaces)
	if strings.Contains(cleaned, " ") {
		return false, "Username cannot contain spaces"
	}

	// Safety check
	if valid, errMsg := ValidateTextSafety(cleaned); !valid {
		return false, errMsg
	}

	length := utf8.RuneCountInString(cleaned)

	if length < 3 {
		return false, "Username must be at least 3 characters"
	}

	if length > 50 {
		return false, "Username must be no more than 50 characters"
	}

	// Check for valid characters (alphanumeric, underscore, hyphen)
	validUsername := regexp.MustCompile(`^[a-zA-Z0-9_\-]+$`)
	if !validUsername.MatchString(cleaned) {
		return false, "Username can only contain letters, numbers, underscores, and hyphens"
	}

	return true, ""
}

// ValidateEmail checks if email is valid
func ValidateEmail(email string) (bool, string) {
	// ✅ NEW: Check for ANY spaces (email should never have spaces)
	if strings.Contains(email, " ") {
		return false, "Email cannot contain spaces"
	}

	if !emailRegex.MatchString(email) {
		return false, "Invalid email format (must include domain like @example.com)"
	}

	length := utf8.RuneCountInString(email)
	if length > 100 {
		return false, "Email must be no more than 100 characters"
	}

	return true, ""
}

// ValidatePassword checks if password meets strong password policy
// Requirements:
// - 8-128 characters
// - At least one uppercase letter
// - At least one lowercase letter
// - At least one digit
// - At least one special character
// - No spaces
func ValidatePassword(password string) (bool, string) {
	length := utf8.RuneCountInString(password)

	// Check minimum length
	if length < 8 {
		return false, "Password must be at least 8 characters"
	}

	// Check maximum length
	if length > 128 {
		return false, "Password must be no more than 128 characters"
	}

	// Check for spaces (already doing this - keep it!)
	if strings.Contains(password, " ") {
		return false, "Password cannot contain spaces"
	}

	// Check for at least one uppercase letter
	hasUpper := false
	for _, char := range password {
		if unicode.IsUpper(char) {
			hasUpper = true
			break
		}
	}
	if !hasUpper {
		return false, "Password must contain at least one uppercase letter"
	}

	// Check for at least one lowercase letter
	hasLower := false
	for _, char := range password {
		if unicode.IsLower(char) {
			hasLower = true
			break
		}
	}
	if !hasLower {
		return false, "Password must contain at least one lowercase letter"
	}

	// Check for at least one digit
	hasDigit := false
	for _, char := range password {
		if unicode.IsDigit(char) {
			hasDigit = true
			break
		}
	}
	if !hasDigit {
		return false, "Password must contain at least one number"
	}

	// Check for at least one special character
	hasSpecial := false
	for _, char := range password {
		// Special characters are anything that's not letter, digit, or space
		if !unicode.IsLetter(char) && !unicode.IsDigit(char) && !unicode.IsSpace(char) {
			hasSpecial = true
			break
		}
	}
	if !hasSpecial {
		return false, "Password must contain at least one special character (!@#$%^&*)"
	}

	return true, ""
}

// ValidatePostTitle checks if post title is valid and safe
func ValidatePostTitle(title string) (bool, string) {
	// Clean dangerous Unicode only (preserves spaces)
	cleaned := CleanText(title)

	// ✅ NEW: Remove newlines and tabs from titles (should be single line)
	cleaned = strings.ReplaceAll(cleaned, "\n", " ")
	cleaned = strings.ReplaceAll(cleaned, "\r", " ")
	cleaned = strings.ReplaceAll(cleaned, "\t", " ")

	// ✅ NEW: Collapse multiple spaces
	for strings.Contains(cleaned, "  ") {
		cleaned = strings.ReplaceAll(cleaned, "  ", " ")
	}

	// ✅ NEW: Check for leading/trailing spaces FIRST
	if cleaned != strings.TrimSpace(cleaned) {
		return false, "Title cannot have spaces at the beginning or end"
	}

	// Safety check
	if valid, errMsg := ValidateTextSafety(cleaned); !valid {
		return false, errMsg
	}

	length := utf8.RuneCountInString(cleaned)

	if length == 0 {
		return false, "Title is required"
	}

	if length < 3 {
		return false, "Title must be at least 3 characters"
	}

	if length > 255 {
		return false, "Title must be no more than 255 characters"
	}

	return true, ""
}

// ValidatePostContent checks if post content is valid and safe
func ValidatePostContent(content string) (bool, string) {
	// Clean dangerous Unicode only (preserves spaces)
	cleaned := CleanText(content)

	// ✅ NEW: Normalize line endings
	cleaned = strings.ReplaceAll(cleaned, "\r\n", "\n") // Windows → Unix
	cleaned = strings.ReplaceAll(cleaned, "\r", "\n")   // Old Mac → Unix

	// ✅ NEW: Convert tabs to spaces for consistent display
	cleaned = strings.ReplaceAll(cleaned, "\t", "    ") // Tab → 4 spaces

	// ✅ NEW: Check for leading/trailing spaces FIRST
	if cleaned != strings.TrimSpace(cleaned) {
		return false, "Content cannot have spaces at the beginning or end"
	}

	// Safety check
	if valid, errMsg := ValidateTextSafety(cleaned); !valid {
		return false, errMsg
	}

	length := utf8.RuneCountInString(cleaned)

	if length == 0 {
		return false, "Content is required"
	}

	if length < 10 {
		return false, "Content must be at least 10 characters"
	}

	if length > 10000 {
		return false, "Content must be no more than 10,000 characters"
	}

	return true, ""
}

// ValidateCommentContent checks if comment content is valid and safe
func ValidateCommentContent(content string) (bool, string) {
	// Clean dangerous Unicode only (preserves spaces)
	cleaned := CleanText(content)

	// ✅ NEW: Normalize line endings
	cleaned = strings.ReplaceAll(cleaned, "\r\n", "\n") // Windows → Unix
	cleaned = strings.ReplaceAll(cleaned, "\r", "\n")   // Old Mac → Unix

	// ✅ NEW: Convert tabs to spaces for consistent display
	cleaned = strings.ReplaceAll(cleaned, "\t", "    ") // Tab → 4 spaces

	// ✅ NEW: Check for leading/trailing spaces FIRST
	if cleaned != strings.TrimSpace(cleaned) {
		return false, "Comment cannot have spaces at the beginning or end"
	}

	// Safety check
	if valid, errMsg := ValidateTextSafety(cleaned); !valid {
		return false, errMsg
	}

	length := utf8.RuneCountInString(cleaned)

	if length == 0 {
		return false, "Comment content is required"
	}

	if length < 10 {
		return false, "Comment must be at least 10 characters"
	}

	if length > 5000 {
		return false, "Comment must be no more than 5,000 characters"
	}

	return true, ""
}

// ValidateCategories checks if category selection is valid
func ValidateCategories(categoryIDs []int) (bool, string) {
	if len(categoryIDs) == 0 {
		return false, "At least one category is required"
	}

	if len(categoryIDs) > 5 {
		return false, "You can select up to 5 categories"
	}

	return true, ""
}
