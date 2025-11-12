package handlers

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
)

// RenderError renders error pages (404, 405, etc.)
// Falls back to inline HTML if error.html template is missing
func RenderError(w http.ResponseWriter, statusCode int, title, message string) {
	w.WriteHeader(statusCode)
	tmpl, err := template.ParseFiles("web/templates/error.html")
	if err != nil {
		// Template missing - use inline HTML fallback
		log.Printf("Error template missing: %v", err)
		renderErrorFallback(w, statusCode, title, message)
		return
	}

	data := map[string]interface{}{
		"StatusCode": statusCode,
		"Title":      title,
		"Message":    message,
	}

	err = tmpl.Execute(w, data)
	if err != nil {
		// Template execution failed - use inline HTML fallback
		log.Printf("Error template execution failed: %v", err)
		renderErrorFallback(w, statusCode, title, message)
		return
	}
}

// renderErrorFallback renders a generic error page with inline HTML
// Used when error.html template is unavailable
func renderErrorFallback(w http.ResponseWriter, statusCode int, title, message string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	html := fmt.Sprintf(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>%d - %s</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 0; 
            padding: 0; 
            background-color: #f5f5f5;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .error-container {
            background: white;
            padding: 50px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 600px;
        }
        .error-code {
            font-size: 72px;
            font-weight: bold;
            color: #dc3545;
            margin: 0;
        }
        .error-title {
            font-size: 32px;
            color: #333;
            margin: 20px 0;
        }
        .error-message {
            font-size: 18px;
            color: #666;
            margin: 20px 0;
            line-height: 1.6;
        }
        .btn {
            display: inline-block;
            background: #007bff;
            color: white;
            padding: 12px 30px;
            border-radius: 5px;
            text-decoration: none;
            margin-top: 30px;
            font-size: 16px;
        }
        .btn:hover {
            background: #0056b3;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="error-code">%d</div>
        <h1 class="error-title">%s</h1>
        <p class="error-message">%s</p>
        <a href="/" class="btn">Go to Homepage</a>
    </div>
</body>
</html>
	`, statusCode, title, statusCode, title, message)

	w.Write([]byte(html))
}

// Render500 renders a 500 error page for template errors
// Always uses inline HTML (can't rely on templates when templates are broken)
func Render500(w http.ResponseWriter, logMessage string) {
	if logMessage != "" {
		log.Printf("500 Error: %s", logMessage)
	}

	w.WriteHeader(http.StatusInternalServerError)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>500 - Server Error</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 0; 
            padding: 0; 
            background-color: #f5f5f5;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .error-container {
            background: white;
            padding: 50px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 600px;
        }
        .error-code {
            font-size: 72px;
            font-weight: bold;
            color: #dc3545;
            margin: 0;
        }
        .error-title {
            font-size: 32px;
            color: #333;
            margin: 20px 0;
        }
        .error-message {
            font-size: 18px;
            color: #666;
            margin: 20px 0;
            line-height: 1.6;
        }
        .btn {
            display: inline-block;
            background: #007bff;
            color: white;
            padding: 12px 30px;
            border-radius: 5px;
            text-decoration: none;
            margin-top: 30px;
            font-size: 16px;
        }
        .btn:hover {
            background: #0056b3;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="error-code">500</div>
        <h1 class="error-title">Internal Server Error</h1>
        <p class="error-message">We encountered a template error. Please try again later.</p>
        <a href="/" class="btn">Go to Homepage</a>
    </div>
</body>
</html>
	`))
}
