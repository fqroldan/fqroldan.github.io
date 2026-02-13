const RESEARCH_DATA_URL = "data/research.json";

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
