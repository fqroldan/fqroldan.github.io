const RESEARCH_DATA_URL = "data/research.json";
const THEME_STORAGE_KEY = "site_theme";
const MOON_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></svg>';
const SUN_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v2.2M12 19.3v2.2M4.7 4.7l1.6 1.6M17.7 17.7l1.6 1.6M2.5 12h2.2M19.3 12h2.2M4.7 19.3l1.6-1.6M17.7 6.3l1.6-1.6"/></svg>';

const getTimeBasedTheme = () => {
  const hour = new Date().getHours();
  return hour >= 7 && hour < 19 ? "light" : "dark";
};

const readThemePreference = () => {
  try {
    const theme = window.localStorage.getItem(THEME_STORAGE_KEY);
    if (theme === "dark" || theme === "light") {
      return theme;
    }
  } catch (error) {
  }
  try {
    const theme = window.sessionStorage.getItem(THEME_STORAGE_KEY);
    if (theme === "dark" || theme === "light") {
      return theme;
    }
  } catch (error) {
  }
  return null;
};

const writeThemePreference = (theme) => {
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch (error) {
  }
  try {
    window.sessionStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch (error) {
  }
};

const initThemeToggle = () => {
  const nav = document.querySelector("nav.nav");
  if (!nav || nav.querySelector(".theme-toggle")) {
    return;
  }

  const root = document.documentElement;

  const applyTheme = (theme) => {
    root.setAttribute("data-theme", theme);
    writeThemePreference(theme);
    toggleButton.innerHTML = theme === "dark" ? SUN_ICON : MOON_ICON;
    toggleButton.setAttribute(
      "aria-label",
      theme === "dark" ? "Switch to light mode" : "Switch to dark mode"
    );
    toggleButton.title = theme === "dark" ? "Switch to light mode" : "Switch to dark mode";
  };

  const toggleButton = document.createElement("button");
  toggleButton.type = "button";
  toggleButton.className = "theme-toggle";

  const initialTheme = readThemePreference() || getTimeBasedTheme();
  applyTheme(initialTheme);

  toggleButton.addEventListener("click", () => {
    const currentTheme = root.getAttribute("data-theme") === "dark" ? "dark" : "light";
    applyTheme(currentTheme === "dark" ? "light" : "dark");
  });

  nav.appendChild(toggleButton);
};

const renderSimpleTable = (table, rows) => {
  const thead = table.querySelector("thead") || table.createTHead();
  const tbody = table.querySelector("tbody") || table.createTBody();
  thead.innerHTML = "";
  tbody.innerHTML = "";

  const headerRow = document.createElement("tr");
  ["Title", "Authors", "Status", "Links"].forEach((label) => {
    const th = document.createElement("th");
    th.textContent = label;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);

  if (!rows.length) {
    const emptyRow = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 4;
    td.textContent = "No items yet.";
    emptyRow.appendChild(td);
    tbody.appendChild(emptyRow);
    return;
  }

  rows.forEach((row) => {
    const tr = document.createElement("tr");
    const titleCell = document.createElement("td");
    titleCell.textContent = row.title || "";
    const authorsCell = document.createElement("td");
    authorsCell.textContent = row.authors || "";
    const statusCell = document.createElement("td");
    statusCell.textContent = row.status || "";
    const linksCell = document.createElement("td");

    if (row.link) {
      const anchor = document.createElement("a");
      anchor.href = row.link;
      anchor.textContent = "link";
      anchor.target = "_blank";
      anchor.rel = "noopener";
      linksCell.appendChild(anchor);
    } else {
      linksCell.textContent = "-";
    }

    tr.appendChild(titleCell);
    tr.appendChild(authorsCell);
    tr.appendChild(statusCell);
    tr.appendChild(linksCell);
    tbody.appendChild(tr);
  });
};

const initResearchPage = async () => {
  const publicationsTable = document.getElementById("publications-table");
  const workingPapersTable = document.getElementById("working-papers-table");
  const workInProgressTable = document.getElementById("work-in-progress-table");

  if (!publicationsTable || !workingPapersTable || !workInProgressTable) {
    return;
  }

  try {
    const response = await fetch(RESEARCH_DATA_URL);
    const data = await response.json();
    renderSimpleTable(publicationsTable, data.publications || []);
    renderSimpleTable(workingPapersTable, data.workingPapers || []);
    renderSimpleTable(workInProgressTable, data.workInProgress || []);
  } catch (error) {
    renderSimpleTable(publicationsTable, []);
    renderSimpleTable(workingPapersTable, []);
    renderSimpleTable(workInProgressTable, []);
  }
};

initResearchPage();
initThemeToggle();
