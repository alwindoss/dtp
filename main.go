package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"
)

// Request represents a JSON-RPC request
type Request struct {
	Method string        `json:"method"`
	Params []interface{} `json:"params,omitempty"`
	ID     interface{}   `json:"id"`
}

// Response represents a JSON-RPC response
type Response struct {
	Result interface{} `json:"result,omitempty"`
	Error  interface{} `json:"error,omitempty"`
	ID     interface{} `json:"id"`
}

// Plugin handles the datetime functionality
type Plugin struct{}

// InsertDateTime returns current date and time
func (p *Plugin) InsertDateTime() string {
	return time.Now().Format("2006-01-02 15:04:05")
}

// InsertDate returns current date
func (p *Plugin) InsertDate() string {
	return time.Now().Format("2006-01-02")
}

// GetCurrentTime returns current time
func (p *Plugin) GetCurrentTime() string {
	return time.Now().Format("2006-01-02 15:04:05")
}

func main() {
	plugin := &Plugin{}
	scanner := bufio.NewScanner(os.Stdin)

	// Log to file for debugging
	logFile, _ := os.OpenFile("/tmp/datetime-plugin-simple.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	defer logFile.Close()

	fmt.Fprintln(logFile, "Plugin started at", time.Now())

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		fmt.Fprintln(logFile, "Received:", line)

		var req Request
		if err := json.Unmarshal([]byte(line), &req); err != nil {
			fmt.Fprintln(logFile, "JSON unmarshal error:", err)
			continue
		}

		var result interface{}
		var errMsg interface{}

		switch req.Method {
		case "InsertDateTime":
			result = plugin.InsertDateTime()
		case "InsertDate":
			result = plugin.InsertDate()
		case "GetCurrentTime":
			result = plugin.GetCurrentTime()
		default:
			errMsg = fmt.Sprintf("Unknown method: %s", req.Method)
		}

		resp := Response{
			Result: result,
			Error:  errMsg,
			ID:     req.ID,
		}

		respJSON, err := json.Marshal(resp)
		if err != nil {
			fmt.Fprintln(logFile, "JSON marshal error:", err)
			continue
		}

		fmt.Println(string(respJSON))
		fmt.Fprintln(logFile, "Sent:", string(respJSON))
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintln(logFile, "Scanner error:", err)
	}

	fmt.Fprintln(logFile, "Plugin stopped at", time.Now())
}
