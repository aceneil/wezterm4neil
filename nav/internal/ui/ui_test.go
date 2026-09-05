package ui

import (
	"strings"
	"testing"

	"github.com/wezterm4neil/wznav/internal/servers"
)

func TestModel_InitialStateLoadsServers(t *testing.T) {
	m := NewModel("/tmp", nil)
	// servers.Load() depends on the host's ~/.ssh/config, but we know the
	// model must initialise without panicking and produce a non-nil view.
	if m.focus != paneServers {
		t.Fatalf("expected default focus paneServers, got %v", m.focus)
	}
	if m.fileView == nil {
		t.Fatalf("fileView not initialised")
	}
	v := m.View()
	if !strings.Contains(v, "wznav") {
		t.Fatalf("View() missing title: %q", v)
	}
	if !strings.Contains(v, "Servers") {
		t.Fatalf("View() missing Servers header")
	}
	if !strings.Contains(v, "Files") {
		t.Fatalf("View() missing Files header")
	}
}

func TestModel_RebuildServerView_FilterMatches(t *testing.T) {
	m := NewModel("/tmp", nil)
	m.serversAll = []servers.Entry{
		{Alias: "alpha", Source: "ssh", SshAlias: "alpha"},
		{Alias: "beta-host", Source: "ssh", SshAlias: "beta-host"},
		{Alias: "gamma", Source: "extra", SshAlias: "gamma", Desc: "Gamma desc"},
	}
	m.serverFilter = "beta"
	m.rebuildServerView()
	if len(m.serversView) != 1 || m.serversView[0].Alias != "beta-host" {
		t.Fatalf("filter wrong: %v", m.serversView)
	}
}

func TestModel_RebuildServerView_EmptyAfterFilter(t *testing.T) {
	m := NewModel("/tmp", nil)
	m.serversAll = []servers.Entry{{Alias: "x", Source: "ssh"}}
	m.serverFilter = "no-match"
	m.rebuildServerView()
	if len(m.serversView) != 0 {
		t.Fatalf("expected empty view, got %v", m.serversView)
	}
	// Cursor should clamp to 0 (last valid index = 0 in empty state).
	if m.serverCursor != 0 {
		t.Fatalf("expected cursor clamp to 0, got %d", m.serverCursor)
	}
}

func TestModel_ServerPaneRendersMarker(t *testing.T) {
	m := NewModel("/tmp", nil)
	m.serversAll = []servers.Entry{{Alias: "testhost", Source: "ssh", SshAlias: "testhost"}}
	m.serversView = m.serversAll
	m.serverCursor = 0
	m.width = 40
	m.height = 12
	v := m.View()
	if !strings.Contains(v, "▶ testhost") && !strings.Contains(v, "testhost") {
		t.Fatalf("expected testhost in view: %q", v)
	}
}

func TestModel_FilterEditClears(t *testing.T) {
	m := NewModel("/tmp", nil)
	m.editingFilter = true
	m.serverFilter = "abc"
	if m.currentFilter() != "abc" {
		t.Fatalf("expected abc, got %q", m.currentFilter())
	}
	m.clearFilter()
	if m.serverFilter != "" {
		t.Fatalf("expected clear, got %q", m.serverFilter)
	}
	if !m.editingFilter {
		t.Fatalf("clearFilter() must NOT touch editingFilter (esc/enter does that)")
	}
}
