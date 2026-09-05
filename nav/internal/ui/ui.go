// Package ui wires the wznav TUI on top of bubbletea. Layout:
//
//	┌─ Servers ─────────────┐
//	│ a1                    │
//	│ a2   (highlighted)    │   ← arrow keys / j/k move; click selects;
//	│ a3                    │     double-click or Enter triggers action
//	├───────────────────────┤
//	│ Files (cwd: ~/)       │
//	│ ..                    │
//	│ dir1/                 │   ← same keys; Enter on file → wz-open.sh;
//	│ dir2/                 │     Enter on dir  → navigate in
//	│ ······                │   ← section divider
//	│ ▶ Files (cwd: ~/)     │
//	│ file.txt              │
//	├───────────────────────┤
//	│ ctx: local  | ? help  │
//	└───────────────────────┘
//
// Panes are tab-cycled with Tab / 1 / 2. '/' filters the active pane.
// On startup the program also boots the local websocket server from
// internal/ws (best-effort, never blocks the TUI).
package ui

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/wezterm4neil/wznav/internal/action"
	"github.com/wezterm4neil/wznav/internal/fs"
	"github.com/wezterm4neil/wznav/internal/servers"
	"github.com/wezterm4neil/wznav/internal/ws"
)

// pane identifies which pane currently owns focus.
type pane int

const (
	paneServers pane = iota
	paneFiles
)

// Model is the bubbletea model. All state lives here; bubbletea guarantees
// single-threaded Update access.
type Model struct {
	width, height int

	focus pane

	serversAll   []servers.Entry
	serversView  []servers.Entry
	serverCursor int
	serverFilter string

	files      *fs.Browser
	fileView   []fs.Item
	fileCur    int
	fileFilter string

	editingFilter bool

	status string // transient bottom-line message (right side)

	ctx string // "local" or last-selected ssh alias
	wss *ws.Server

	// Mouse double-click detection.
	lastClickAt time.Time
	lastClickX  int
	lastClickY  int
}

// NewModel constructs the initial model. The websocket server is built
// but not started here; main() calls ws.Start so we can hand back the
// URL for logging even if startup fails.
func NewModel(startDir string, wss *ws.Server) *Model {
	m := &Model{
		focus:      paneServers,
		files:      fs.New(startDir),
		ctx:        "local",
		wss:        wss,
		serversAll: servers.Load(),
	}
	m.rebuildServerView()
	m.refreshFiles()
	return m
}

// tickMsg drives the status-line auto-expiry.
type tickMsg time.Time

// Init is required by bubbletea. We tick every 750ms so the transient
// status message can self-clear after a few seconds.
func (m *Model) Init() tea.Cmd {
	return tea.Tick(750*time.Millisecond, func(t time.Time) tea.Msg { return tickMsg(t) })
}

// ----- Update --------------------------------------------------------------

// Update is the bubbletea message dispatcher.
func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		return m, nil
	case tea.KeyMsg:
		return m.handleKey(msg)
	case tea.MouseMsg:
		return m.handleMouse(msg)
	case tickMsg:
		// Every tick is a chance to clear stale status. We re-arm the timer.
		return m, tea.Tick(750*time.Millisecond, func(t time.Time) tea.Msg { return tickMsg(t) })
	default:
		return m, nil
	}
}

func (m *Model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	// If we're in filter-edit mode, every printable key edits the buffer.
	if m.editingFilter {
		return m.handleFilterKey(msg)
	}
	switch msg.String() {
	case "ctrl+c":
		return m, tea.Quit
	case "q":
		return m, tea.Quit
	case "tab":
		m.focus = (m.focus + 1) % 2
		m.clearFilter()
		return m, nil
	case "1":
		m.focus = paneServers
		m.clearFilter()
		return m, nil
	case "2":
		m.focus = paneFiles
		m.clearFilter()
		return m, nil
	case "?":
		m.status = "j/k move · enter open · / filter · 1/2 panes · tab cycle · r refresh · ? help · q quit"
		return m, nil
	case "r":
		m.reloadServers()
		m.refreshFiles()
		m.status = "refreshed"
		return m, nil
	case "/":
		m.editingFilter = true
		m.status = ""
		return m, nil
	}
	switch m.focus {
	case paneServers:
		return m.handleServersKey(msg)
	case paneFiles:
		return m.handleFilesKey(msg)
	}
	return m, nil
}

func (m *Model) handleServersKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "j", "down":
		if m.serverCursor < len(m.serversView)-1 {
			m.serverCursor++
		}
	case "k", "up":
		if m.serverCursor > 0 {
			m.serverCursor--
		}
	case "g":
		m.serverCursor = 0
	case "G":
		if len(m.serversView) > 0 {
			m.serverCursor = len(m.serversView) - 1
		}
	case "enter":
		m.openSelectedServer()
	}
	return m, nil
}

func (m *Model) handleFilesKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "j", "down":
		if m.fileCur < len(m.fileView)-1 {
			m.fileCur++
		}
	case "k", "up":
		if m.fileCur > 0 {
			m.fileCur--
		}
	case "h", "left":
		if err := m.files.Parent(); err != nil {
			m.status = err.Error()
		} else {
			m.status = ""
			m.refreshFiles()
		}
	case "l", "right":
		m.enterSelectedFile()
	case "enter":
		m.enterSelectedFile()
	}
	return m, nil
}

func (m *Model) handleFilterKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.editingFilter = false
		m.clearFilter()
	case "enter":
		m.editingFilter = false
	case "backspace":
		switch m.focus {
		case paneServers:
			if len(m.serverFilter) > 0 {
				m.serverFilter = m.serverFilter[:len(m.serverFilter)-1]
				m.rebuildServerView()
			}
		case paneFiles:
			if len(m.fileFilter) > 0 {
				m.fileFilter = m.fileFilter[:len(m.fileFilter)-1]
				m.rebuildFileView()
			}
		}
	default:
		s := msg.String()
		if len(s) == 1 && s[0] >= 32 && s[0] < 127 {
			switch m.focus {
			case paneServers:
				m.serverFilter += s
				m.rebuildServerView()
			case paneFiles:
				m.fileFilter += s
				m.rebuildFileView()
			}
		}
	}
	return m, nil
}

func (m *Model) clearFilter() {
	if m.serverFilter != "" {
		m.serverFilter = ""
		m.rebuildServerView()
	}
	if m.fileFilter != "" {
		m.fileFilter = ""
		m.rebuildFileView()
	}
}

func (m *Model) currentFilter() string {
	if m.focus == paneServers {
		return m.serverFilter
	}
	return m.fileFilter
}

func (m *Model) rebuildServerView() {
	q := strings.ToLower(m.serverFilter)
	if q == "" {
		m.serversView = append([]servers.Entry(nil), m.serversAll...)
		m.serverCursor = clamp(m.serverCursor, 0, max(0, len(m.serversView)-1))
		return
	}
	var out []servers.Entry
	for _, e := range m.serversAll {
		if strings.Contains(strings.ToLower(e.Alias), q) ||
			strings.Contains(strings.ToLower(e.Desc), q) {
			out = append(out, e)
		}
	}
	m.serversView = out
	m.serverCursor = clamp(m.serverCursor, 0, max(0, len(m.serversView)-1))
}

func (m *Model) rebuildFileView() {
	m.refreshFiles()
	q := strings.ToLower(m.fileFilter)
	if q == "" {
		return
	}
	var out []fs.Item
	for _, it := range m.fileView {
		if strings.Contains(strings.ToLower(it.Name), q) {
			out = append(out, it)
		}
	}
	m.fileView = out
	m.fileCur = clamp(m.fileCur, 0, max(0, len(m.fileView)-1))
}

// ----- Mouse handling -------------------------------------------------------

func (m *Model) handleMouse(msg tea.MouseMsg) (tea.Model, tea.Cmd) {
	_, y := msg.X, msg.Y
	switch msg.Type {
	case tea.MouseLeft:
		// Detect double-click via timestamp+position heuristic.
		double := !m.lastClickAt.IsZero() &&
			time.Since(m.lastClickAt) < 500*time.Millisecond &&
			m.lastClickX == msg.X && m.lastClickY == msg.Y
		m.lastClickAt = time.Now()
		m.lastClickX = msg.X
		m.lastClickY = msg.Y
		if y >= 2 && y < m.serverListEnd() {
			m.focus = paneServers
			m.serverCursor = clamp(y-2, 0, max(0, len(m.serversView)-1))
			if double {
				m.openSelectedServer()
			}
			return m, nil
		}
			if y >= m.serverListEnd()+2 && y < m.height-1 {
				m.focus = paneFiles
				m.fileCur = clamp(y-(m.serverListEnd()+2), 0, max(0, len(m.fileView)-1))
			if double {
				m.enterSelectedFile()
			}
			return m, nil
		}
	case tea.MouseWheelUp, tea.MouseWheelDown:
		k := tea.KeyMsg{Type: tea.KeyDown}
		if msg.Type == tea.MouseWheelUp {
			k = tea.KeyMsg{Type: tea.KeyUp}
		}
		if m.focus == paneServers {
			return m.handleServersKey(k)
		}
		return m.handleFilesKey(k)
	}
	return m, nil
}

// serverListEnd returns the row index of the section divider (between
// servers and the file header). Layout:
// title (0), server header (1), servers (2..sEnd-1), divider (sEnd),
// file header (sEnd+1), files (sEnd+2..height-2), status (last).
func (m *Model) serverListEnd() int {
	usable := m.height - 1 // leave 1 for status
	if usable < 6 {
		usable = 6
	}
	serverH := usable / 2
	return 2 + serverH
}

// ----- Operations ----------------------------------------------------------

func (m *Model) openSelectedServer() {
	if len(m.serversView) == 0 {
		m.status = "no servers to open (refresh with r)"
		return
	}
	sel := m.serversView[m.serverCursor]
	plan := action.Build(sel)
	m.ctx = servers.TabName(sel)
	if m.wss != nil {
		m.wss.SetContext(m.ctx)
	}
	m.status = fmt.Sprintf("→ %s  (zellij=%s)", plan.TabName, plan.Detected)
	if err := action.Run(context.Background(), plan); err != nil {
		m.status = "exec failed: " + err.Error()
	}
}

func (m *Model) enterSelectedFile() {
	if len(m.fileView) == 0 {
		return
	}
	name := m.fileView[m.fileCur].Name
	if name == ".." {
		_ = m.files.Parent()
		m.refreshFiles()
		return
	}
	full := m.files.PathOf(name)
	if m.files.IsDir(name) {
		if _, err := m.files.Into(name); err != nil {
			m.status = err.Error()
			return
		}
		m.refreshFiles()
		return
	}
	// File: prefer wz-open.sh, then xdg-open.
	if path, err := exec.LookPath("wz-open.sh"); err == nil {
		cmd := exec.Command(path, full) //nolint:gosec
		_ = cmd.Start()
		go func() { _ = cmd.Wait() }()
		m.status = "opened: " + full
		return
	}
	if path, err := exec.LookPath("xdg-open"); err == nil {
		cmd := exec.Command(path, full) //nolint:gosec
		_ = cmd.Start()
		go func() { _ = cmd.Wait() }()
		m.status = "xdg-open: " + full
		return
	}
	m.status = "no opener (install ~/.local/bin/wz-open.sh)"
}

func (m *Model) reloadServers() {
	m.serversAll = servers.Load()
	m.rebuildServerView()
}

func (m *Model) refreshFiles() {
	items, err := m.files.ListDir()
	if err != nil {
		m.status = "fs: " + err.Error()
		return
	}
	if m.files.Current != "/" {
		items = append([]fs.Item{{Name: "..", IsDir: true}}, items...)
	}
	m.fileView = items
	if m.fileFilter != "" {
		m.rebuildFileView()
		return
	}
	m.fileCur = clamp(m.fileCur, 0, max(0, len(m.fileView)-1))
}

// ----- View -----------------------------------------------------------------

func (m *Model) View() string {
	var b strings.Builder
	if m.width == 0 {
		m.width = 80
	}
	if m.height == 0 {
		m.height = 24
	}

	// Title.
	b.WriteString(pad(" wznav ", m.width, '-'))
	b.WriteByte('\n')

	// Server header.
	shead := "Servers"
	if m.focus == paneServers {
		shead = "▶ Servers"
	}
	b.WriteString(pad(" "+shead+" ", m.width, '-'))
	b.WriteByte('\n')

	// Server rows.
	serverH := m.serverListEnd() - 2
	for i := 0; i < serverH; i++ {
		b.WriteString(m.renderServerRow(i))
		b.WriteByte('\n')
	}

	// Section divider between server list and file manager.
	b.WriteString(pad("", m.width, '·'))
	b.WriteByte('\n')

	// File header.
	fhead := fmt.Sprintf("Files (%s)", m.files.Current)
	if m.focus == paneFiles {
		fhead = "▶ " + fhead
	}
	b.WriteString(pad(" "+fhead+" ", m.width, '-'))
	b.WriteByte('\n')

	// File rows.
	fileRows := m.height - m.serverListEnd() - 3
	if fileRows < 1 {
		fileRows = 1
	}
	for i := 0; i < fileRows; i++ {
		b.WriteString(m.renderFileRow(i))
		if i < fileRows-1 {
			b.WriteByte('\n')
		}
	}

	// Status bar.
	b.WriteByte('\n')
	b.WriteString(m.statusLine())
	return b.String()
}

func (m *Model) renderServerRow(i int) string {
	if i >= len(m.serversView) {
		return blank(m.width)
	}
	e := m.serversView[i]
	marker := "  "
	if i == m.serverCursor {
		if m.focus == paneServers {
			marker = "▶ "
		} else {
			marker = "▷ "
		}
	}
	desc := ""
	if e.Desc != "" {
		desc = "  (" + e.Desc + ")"
	}
	label := e.Alias + desc
	if e.Source == "extra" {
		label += "  [extra]"
	}
	return trunc(pad(marker+label, m.width, ' '), m.width)
}

func (m *Model) renderFileRow(i int) string {
	if i >= len(m.fileView) {
		return blank(m.width)
	}
	it := m.fileView[i]
	marker := "  "
	if i == m.fileCur {
		if m.focus == paneFiles {
			marker = "▶ "
		} else {
			marker = "▷ "
		}
	}
	var label string
	if it.IsDir {
		label = marker + it.Name + "/"
	} else {
		label = marker + it.Name
	}
	return trunc(pad(label, m.width, ' '), m.width)
}

func (m *Model) statusLine() string {
	filter := ""
	if m.editingFilter {
		filter = " filter:" + m.currentFilter() + "_"
	} else if m.currentFilter() != "" {
		filter = " filter:" + m.currentFilter()
	}
	left := fmt.Sprintf(" ctx=%s pane=%d ws=%s%s", m.ctx, m.focus+1, m.wssURL(), filter)
	right := m.status
	if right != "" {
		right = "  |  " + right
	}
	row := left + right
	return trunc(pad(row, m.width, ' '), m.width)
}

func (m *Model) wssURL() string {
	if m.wss == nil {
		return "off"
	}
	return m.wss.URL()
}

// ----- helpers -------------------------------------------------------------

func pad(s string, w int, fill byte) string {
	if len(s) >= w {
		return s
	}
	return s + strings.Repeat(string(fill), w-len(s))
}

func blank(w int) string {
	if w <= 0 {
		return ""
	}
	return strings.Repeat(" ", w)
}

func trunc(s string, w int) string {
	if w <= 0 {
		return ""
	}
	if len(s) <= w {
		return s
	}
	return s[:w]
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
