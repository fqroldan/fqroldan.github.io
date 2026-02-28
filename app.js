const CONFIG = {
  APPS_SCRIPT_URL: "https://script.google.com/macros/s/AKfycbznCrokySiyUNF9YsAsDGOUZ_aj4gWnZPwdyQpnU_gbHgHSWpaWC4jrBP778yxg3Bu0BQ/exec",
  ADMIN_KEY_STORAGE: "rrg_admin_key",
  VERIFIED_STORAGE: "rrg_verified"
};

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

const MEETING_COLUMNS = [
  "meeting",
  "participant",
  "email",
  "title",
  "authors",
  "year",
  "journal",
  "doi",
  "link",
  "status",
  "admin_note",
  "slides"
];

const MEETING_COLUMNS_PUBLIC = MEETING_COLUMNS.filter((col) => col !== "email");
const ARCHIVE_COLUMNS = [...MEETING_COLUMNS, "recorded_at"];
const ARCHIVE_COLUMNS_PUBLIC = ARCHIVE_COLUMNS.filter(
  (col) => col !== "email" && col !== "admin_note"
);

const isApiConfigured = () =>
  CONFIG.APPS_SCRIPT_URL && CONFIG.APPS_SCRIPT_URL !== "PASTE_YOUR_APPS_SCRIPT_URL_HERE";

const storage = {
  get(key, fallback = []) {
    const raw = window.localStorage.getItem(key);
    if (!raw) {
      return fallback;
    }
    try {
      return JSON.parse(raw);
    } catch (error) {
      return fallback;
    }
  },
  set(key, value) {
    window.localStorage.setItem(key, JSON.stringify(value));
  }
};

const fileReader = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result || "");
    reader.onerror = () => reject(reader.error);
    reader.readAsText(file);
  });

const escapeCsvValue = (value) => {
  const text = value == null ? "" : String(value);
  if (/[",\n\r]/.test(text)) {
    return `"${text.replace(/"/g, '""')}"`;
  }
  return text;
};

const toCsv = (rows, columns) => {
  const header = columns.join(",");
  const body = rows
    .map((row) => columns.map((key) => escapeCsvValue(row[key])).join(","))
    .join("\n");
  return `${header}\n${body}`.trim();
};

const parseCsvLine = (line) => {
  const result = [];
  let current = "";
  let inQuotes = false;

  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    if (char === '"') {
      const nextChar = line[index + 1];
      if (inQuotes && nextChar === '"') {
        current += '"';
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += char;
    }
  }

  result.push(current);
  return result;
};

const fetchJson = async (url, options = {}) => {
  const response = await fetch(url, options);
  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch (error) {
    throw new Error(text || "Request failed.");
  }
  if (!response.ok || !data.ok) {
    const err = new Error(data.message || "Request failed.");
    err.code = data.code || null;
    throw err;
  }
  return data;
};

const apiUrl = (params) => {
  const query = new URLSearchParams(params).toString();
  return `${CONFIG.APPS_SCRIPT_URL}?${query}`;
};

const postApi = (payload) => {
  const body = new URLSearchParams(payload);
  return fetchJson(CONFIG.APPS_SCRIPT_URL, {
    method: "POST",
    body
  });
};

const parseCsv = (text) => {
  const lines = text.replace(/\r\n/g, "\n").split("\n").filter(Boolean);
  if (lines.length === 0) {
    return { headers: [], rows: [] };
  }
  const headers = parseCsvLine(lines[0]).map((header) => header.trim());
  const rows = lines.slice(1).map((line) => {
    const values = parseCsvLine(line);
    return headers.reduce((acc, header, idx) => {
      acc[header] = values[idx] ?? "";
      return acc;
    }, {});
  });
  return { headers, rows };
};

const normalizeRows = (rows, columns) =>
  rows.map((row) => {
    const normalized = {};
    columns.forEach((column) => {
      normalized[column] = row[column] ?? "";
    });
    return normalized;
  });

const downloadCsv = (filename, rows, columns) => {
  const csv = toCsv(rows, columns);
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
};

const renderTable = (table, rows, columns, emptyText = "No records yet.") => {
  const thead = table.querySelector("thead") || table.createTHead();
  const tbody = table.querySelector("tbody") || table.createTBody();
  thead.innerHTML = "";
  tbody.innerHTML = "";

  const headerRow = document.createElement("tr");
  columns.forEach((column) => {
    const th = document.createElement("th");
    th.textContent = column.label;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);

  if (rows.length === 0) {
    const emptyRow = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = columns.length;
    td.textContent = emptyText;
    emptyRow.appendChild(td);
    tbody.appendChild(emptyRow);
    return;
  }

  rows.forEach((row) => {
    const tr = document.createElement("tr");
    columns.forEach((column) => {
      const td = document.createElement("td");
      const value = row[column.key] || "";
      if (column.key === "slides") {
        if (value && value.startsWith("http")) {
          const anchor = document.createElement("a");
          anchor.href = value;
          anchor.textContent = "link";
          anchor.target = "_blank";
          anchor.rel = "noopener";
          td.appendChild(anchor);
        } else {
          td.textContent = "-";
        }
      } else if (column.key === "link" && value.startsWith("http")) {
        const anchor = document.createElement("a");
        anchor.href = value;
        anchor.textContent = value;
        anchor.target = "_blank";
        anchor.rel = "noopener";
        td.appendChild(anchor);
      } else {
        td.textContent = value;
      }
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
};

const setStatus = (element, message, isError = false) => {
  if (!element) {
    return;
  }
  element.textContent = message;
  element.classList.toggle("error", isError);
};

const NEXT_MEETING_CUTOFF = "2026-03-01";

const friendlyMessage = (message) => {
  if (message === "Email not authorized.") {
    return "Email not authorized. Contact froldan@nyu.edu to be added.";
  }
  if (message === "Invalid or expired verification.") {
    return "Verification expired. Please verify again.";
  }
  if (message === "Invalid or expired verification code.") {
    return "Verification code expired or invalid. Request a new code.";
  }
  return message;
};

const getNextWednesday = () => {
  const today = new Date();
  const day = today.getDay();
  const baseDiff = (3 - day + 7) % 7;
  const diff = day <= 3 ? baseDiff + 7 : baseDiff;
  const target = new Date(today);
  target.setDate(today.getDate() + diff);
  return target.toISOString().slice(0, 10);
};

const getFirstWednesdayOfMarch = () => {
  const today = new Date();
  let year = today.getFullYear();
  const marchFirst = new Date(year, 2, 1);
  const diff = (3 - marchFirst.getDay() + 7) % 7;
  let target = new Date(year, 2, 1 + diff);
  if (target < today) {
    year += 1;
    const nextMarchFirst = new Date(year, 2, 1);
    const nextDiff = (3 - nextMarchFirst.getDay() + 7) % 7;
    target = new Date(year, 2, 1 + nextDiff);
  }
  return target.toISOString().slice(0, 10);
};

const getCutoffMeetingDate = () => {
  if (!NEXT_MEETING_CUTOFF) {
    return getNextWednesday();
  }
  return getFirstWednesdayOfMarch();
};

const formatReadableDate = (value) => {
  if (!value) {
    return "--";
  }
  const parts = String(value).split("-").map((part) => Number.parseInt(part, 10));
  if (parts.length !== 3 || parts.some((part) => Number.isNaN(part))) {
    return value;
  }
  const [year, month, day] = parts;
  const date = new Date(year, month - 1, day);
  return date.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric"
  });
};

const initSubmissionPage = () => {
  const meetingInput = document.getElementById("meeting-date");
  const submissionForm = document.getElementById("submission-form");
  const slidesForm = document.getElementById("slides-form");
  const table = document.getElementById("meeting-table");
  const status = document.getElementById("submission-status");
  const verificationForm = document.getElementById("verification-form");
  const verifyEmailInput = document.getElementById("verify-email");
  const verifyCodeInput = document.getElementById("verify-code");
  const verifyStatus = document.getElementById("verification-status");
  const verifyHeading = document.getElementById("verify-heading");
  const verifyCodeRow = document.getElementById("verify-code-row");
  const sendCodeButton = document.getElementById("send-code");
  const confirmCodeButton = document.getElementById("confirm-code");
  const clearVerificationButton = document.getElementById("clear-verification");
  const fetchDoiButton = document.getElementById("fetch-doi");
  const doiInput = document.getElementById("doi");
  const submissionEmailInput = document.getElementById("submission-email");
  const nextMeetingDateLabel = document.getElementById("next-meeting-date");
  const slidesStatus = document.getElementById("slides-status");
  const meetingOverrideInput = document.getElementById("meeting-override");

  const columns = [
    { key: "participant", label: "Participant name" },
    { key: "title", label: "Paper title" },
    { key: "authors", label: "Authors" },
    { key: "year", label: "Year" },
    { key: "journal", label: "Journal Name" },
    { key: "link", label: "Link to paper" },
    { key: "status", label: "Status" },
    { key: "slides", label: "Slides" }
  ];

  let meetingRows = [];
  let nextMeetingDate = "";

  const getSelectedMeeting = () =>
    meetingOverrideInput?.checked ? meetingInput.value : nextMeetingDate || meetingInput.value;

  const setMeetingOverride = (isOverride) => {
    meetingInput.disabled = !isOverride;
    if (!isOverride && nextMeetingDate) {
      meetingInput.value = nextMeetingDate;
      nextMeetingDateLabel.textContent = formatReadableDate(nextMeetingDate);
    }
  };

  const setLoading = (isLoading) => {
    status.classList.toggle("is-loading", isLoading);
    status.classList.toggle("is-hidden", !isLoading);
    verifyStatus.classList.toggle("is-loading", isLoading);
  };

  const setVerificationStatus = (message, isError = false) => {
    setStatus(verifyStatus, message, isError);
  };

  const getVerified = () => {
    const raw = window.sessionStorage.getItem(CONFIG.VERIFIED_STORAGE);
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw);
    } catch (error) {
      return null;
    }
  };

  const setVerified = (payload) => {
    window.sessionStorage.setItem(CONFIG.VERIFIED_STORAGE, JSON.stringify(payload));
  };

  const clearVerified = () => {
    window.sessionStorage.removeItem(CONFIG.VERIFIED_STORAGE);
  };

  const setSubmissionLocked = (isLocked) => {
    const controls = submissionForm.querySelectorAll("input, textarea, select, button");
    controls.forEach((control) => {
      control.disabled = isLocked;
    });
  };

  const setSlidesLocked = (isLocked) => {
    const controls = slidesForm.querySelectorAll("input, textarea, select, button");
    controls.forEach((control) => {
      control.disabled = isLocked;
    });
  };

  const applyVerifiedEmail = () => {
    const verified = getVerified();
    if (verified?.email && verified?.sessionToken) {
      submissionEmailInput.value = verified.email;
      verifyEmailInput.value = verified.email;
      verifyHeading.classList.add("is-hidden");
      setVerificationStatus(`Logged in as ${verified.email}.`);
      if (slidesStatus) {
        slidesStatus.textContent = "";
      }
      setVerificationLocked(true);
      setSubmissionLocked(false);
      setSlidesLocked(false);
    } else if (verified?.email) {
      clearVerified();
      submissionEmailInput.value = "";
      verifyHeading.classList.remove("is-hidden");
      setVerificationStatus("Verification expired. Please verify again.", true);
      if (slidesStatus) {
        slidesStatus.textContent = "Session expired. Please verify again to add slides.";
      }
      setVerificationLocked(false);
      setSubmissionLocked(true);
      setSlidesLocked(true);
    } else {
      submissionEmailInput.value = "";
      verifyHeading.classList.remove("is-hidden");
      setVerificationStatus("Please verify your email before proceeding.", true);
      if (slidesStatus) {
        slidesStatus.textContent = "Verify your email to add slides.";
      }
      setVerificationLocked(false);
      setSubmissionLocked(true);
      setSlidesLocked(true);
    }
  };

  const setVerificationLocked = (isLocked) => {
    verifyEmailInput.disabled = isLocked;
    verifyCodeInput.disabled = isLocked;
    if (isLocked) {
      verifyCodeRow.classList.add("is-hidden");
      confirmCodeButton.classList.add("is-hidden");
      sendCodeButton.classList.add("is-hidden");
    }
  };

  const showCodeEntry = () => {
    setVerificationLocked(false);
    verifyCodeRow.classList.remove("is-hidden");
    confirmCodeButton.classList.remove("is-hidden");
    sendCodeButton.classList.add("is-hidden");
    verifyCodeInput.focus();
  };

  const resetVerificationUi = () => {
    verifyCodeRow.classList.add("is-hidden");
    confirmCodeButton.classList.add("is-hidden");
    sendCodeButton.classList.remove("is-hidden");
    verifyEmailInput.disabled = false;
    verifyCodeInput.disabled = false;
  };

  const loadMeeting = async () => {
    if (!isApiConfigured()) {
      setStatus(status, "Set APPS_SCRIPT_URL in app.js to enable submissions.", true);
      return;
    }
    setLoading(true);
    try {
      const meeting = getSelectedMeeting();
      if (meeting) {
        meetingInput.value = meeting;
        nextMeetingDateLabel.textContent = formatReadableDate(meeting);
      }
      const data = await fetchJson(apiUrl({ action: "meeting", meeting }));
      meetingRows = data.rows || [];
      renderTable(table, meetingRows, columns, "No submissions yet.");
    } finally {
      setLoading(false);
    }
  };

  const resolveNextMeeting = async () => {
    if (!isApiConfigured()) {
      return getCutoffMeetingDate();
    }
    try {
      const data = await fetchJson(apiUrl({ action: "nextMeeting" }));
      return data.meeting || getCutoffMeetingDate();
    } catch (error) {
      return getCutoffMeetingDate();
    }
  };

  const fallbackMeeting = getCutoffMeetingDate();
  if (!meetingOverrideInput?.checked) {
    meetingInput.value = fallbackMeeting;
    nextMeetingDateLabel.textContent = formatReadableDate(fallbackMeeting);
  }

  setLoading(true);
  resolveNextMeeting()
    .then((meeting) => {
      nextMeetingDate = meeting;
      if (!meetingOverrideInput?.checked) {
        meetingInput.value = meeting;
        nextMeetingDateLabel.textContent = formatReadableDate(meeting);
      }
      return loadMeeting();
    })
    .catch((error) => setStatus(status, error.message, true));
  applyVerifiedEmail();
  setMeetingOverride(false);

  if (meetingOverrideInput) {
    meetingOverrideInput.addEventListener("change", () => {
      const isOverride = meetingOverrideInput.checked;
      setMeetingOverride(isOverride);
      if (isOverride) {
        meetingInput.focus();
      } else {
        loadMeeting()
          .then(() => setStatus(status, "Loaded submissions for the next meeting."))
          .catch((error) => setStatus(status, error.message, true));
      }
    });
  }

  meetingInput.addEventListener("change", () => {
    if (!meetingOverrideInput?.checked && nextMeetingDate) {
      meetingInput.value = nextMeetingDate;
      nextMeetingDateLabel.textContent = formatReadableDate(nextMeetingDate);
    } else {
      nextMeetingDateLabel.textContent = formatReadableDate(meetingInput.value);
    }
    loadMeeting()
      .then(() => setStatus(status, "Loaded submissions for the selected meeting."))
      .catch((error) => setStatus(status, error.message, true));
  });

  submissionForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const formData = new FormData(submissionForm);
    const verified = getVerified();
    const email = formData.get("email")?.trim() || "";
    const row = {
      meeting: getSelectedMeeting(),
      participant: formData.get("participant")?.trim() || "",
      email,
      title: formData.get("title")?.trim() || "",
      authors: formData.get("authors")?.trim() || "",
      year: formData.get("year")?.trim() || "",
      journal: formData.get("journal")?.trim() || "",
      doi: formData.get("doi")?.trim() || "",
      link: formData.get("link")?.trim() || "",
      status: "pending",
      admin_note: "",
      slides: ""
    };
    if (!row.participant || !row.title || !row.email) {
      setStatus(status, "Participant, email, and paper title are required.", true);
      return;
    }
    if (!verified || verified.email !== email || !verified.sessionToken) {
      setStatus(status, "Please verify your email before submitting.", true);
      return;
    }
    try {
      setLoading(true);
      await postApi({ action: "submit", ...row, sessionToken: verified.sessionToken });
      submissionForm.reset();
      applyVerifiedEmail();
      await loadMeeting();
      setStatus(status, "Submission sent to the admin sheet.");
    } catch (error) {
      if (error.code === "duplicate") {
        const confirmOverwrite = window.confirm(
          "You already have an existing submission for the selected meeting. Do you want to overwrite it?"
        );
        if (!confirmOverwrite) {
          setStatus(status, "Submission kept unchanged.");
          setLoading(false);
          return;
        }
        try {
          setLoading(true);
          await postApi({
            action: "submit",
            ...row,
            sessionToken: verified.sessionToken,
            overwrite: "true"
          });
          submissionForm.reset();
          applyVerifiedEmail();
          await loadMeeting();
          setStatus(status, "Submission updated.");
        } catch (overwriteError) {
          setStatus(status, overwriteError.message, true);
        } finally {
          setLoading(false);
        }
        return;
      }
      setStatus(status, friendlyMessage(error.message), true);
    } finally {
      setLoading(false);
    }
  });

  slidesForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const formData = new FormData(slidesForm);
    const slides = formData.get("slides")?.trim() || "";
    const verified = getVerified();
    const email = verified?.email || "";

    if (!verified || verified.email !== email || !verified.sessionToken) {
      setStatus(status, "Please verify your email before attaching slides.", true);
      return;
    }

    try {
      setLoading(true);
      const statusData = await postApi({
        action: "userStatus",
        meeting: getSelectedMeeting(),
        email,
        sessionToken: verified.sessionToken
      });
      if (!statusData?.status) {
        setStatus(status, "No submission found for this meeting.", true);
        return;
      }
      if (String(statusData.status).toLowerCase() !== "long") {
        const confirmContinue = window.confirm(
          "You have not been selected for a long talk. Do you wish to continue?"
        );
        if (!confirmContinue) {
          setStatus(status, "Slides upload canceled.");
          return;
        }
      }
      await postApi({
        action: "slides",
        meeting: getSelectedMeeting(),
        email,
        slides,
        sessionToken: verified.sessionToken
      });
      slidesForm.reset();
      applyVerifiedEmail();
      await loadMeeting();
      setStatus(status, "Slides link added to the meeting CSV.");
    } catch (error) {
      setStatus(status, friendlyMessage(error.message), true);
    } finally {
      setLoading(false);
    }
  });

  sendCodeButton.addEventListener("click", async () => {
    const email = verifyEmailInput.value.trim();
    if (!email) {
      setVerificationStatus("Email is required.", true);
      return;
    }
    if (!isApiConfigured()) {
      setVerificationStatus("Set APPS_SCRIPT_URL in app.js to enable verification.", true);
      return;
    }
    try {
      setLoading(true);
      await postApi({ action: "requestVerification", email });
      setVerificationStatus("Verification code sent.");
      showCodeEntry();
    } catch (error) {
      setVerificationStatus(friendlyMessage(error.message), true);
    } finally {
      setLoading(false);
    }
  });

  confirmCodeButton.addEventListener("click", async () => {
    const email = verifyEmailInput.value.trim();
    const code = verifyCodeInput.value.trim();
    if (!email || !code) {
      setVerificationStatus("Email and code are required.", true);
      return;
    }
    if (!isApiConfigured()) {
      setVerificationStatus("Set APPS_SCRIPT_URL in app.js to enable verification.", true);
      return;
    }
    try {
      setLoading(true);
      const { sessionToken } = await postApi({ action: "verify", email, code });
      setVerified({ email, sessionToken });
      applyVerifiedEmail();
      const participantInput = submissionForm.querySelector("input[name='participant']");
      if (participantInput) {
        participantInput.focus();
      }
    } catch (error) {
      setVerificationStatus(friendlyMessage(error.message), true);
    } finally {
      setLoading(false);
    }
  });

  clearVerificationButton.addEventListener("click", () => {
    clearVerified();
    verifyEmailInput.value = "";
    verifyCodeInput.value = "";
    resetVerificationUi();
    setVerificationStatus("Verification cleared.");
    applyVerifiedEmail();
  });

  verifyCodeInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      confirmCodeButton.click();
    }
  });

  verifyEmailInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !sendCodeButton.classList.contains("is-hidden")) {
      event.preventDefault();
      sendCodeButton.click();
    }
  });

  doiInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      fetchDoiButton.click();
    }
  });

  fetchDoiButton.addEventListener("click", async () => {
    const doi = doiInput.value.trim();
    if (!doi) {
      setStatus(status, "Enter a DOI to fetch details.", true);
      return;
    }
    try {
      setLoading(true);
      const response = await fetch(`https://api.crossref.org/works/${encodeURIComponent(doi)}`);
      const data = await response.json();
      if (!response.ok || !data.message) {
        throw new Error("DOI lookup failed.");
      }
      const message = data.message;
      const title = Array.isArray(message.title) ? message.title[0] : "";
      const authors = Array.isArray(message.author)
        ? message.author
            .map((author) => [author.given, author.family].filter(Boolean).join(" "))
            .filter(Boolean)
            .join(", ")
        : "";
      const journal = Array.isArray(message["container-title"])
        ? message["container-title"][0]
        : "";
      const year = Array.isArray(message.issued?.["date-parts"])
        ? message.issued["date-parts"]?.[0]?.[0]
        : "";
      const link = message.URL || "";

      if (title) {
        submissionForm.querySelector("input[name='title']").value = title;
      }
      if (authors) {
        submissionForm.querySelector("input[name='authors']").value = authors;
      }
      if (journal) {
        submissionForm.querySelector("input[name='journal']").value = journal;
      }
      if (year) {
        submissionForm.querySelector("input[name='year']").value = String(year);
      }
      if (link) {
        submissionForm.querySelector("input[name='link']").value = link;
      }
      setStatus(status, "DOI details loaded.");
    } catch (error) {
      setStatus(status, error.message, true);
    } finally {
      setLoading(false);
    }
  });
};

const initArchivePage = () => {
  const archiveAccordion = document.getElementById("archive-accordion");
  const archiveStatus = document.getElementById("archive-status");
  const syncButton = document.getElementById("sync-archive");
  const meetingTable = document.getElementById("archive-meeting-table");
  const meetingStatus = document.getElementById("archive-meeting-status");
  const meetingDateLabel = document.getElementById("archive-meeting-date");

  const columns = [
    { key: "participant", label: "Participant" },
    { key: "title", label: "Paper" },
    { key: "authors", label: "Authors" },
    { key: "year", label: "Year" },
    { key: "journal", label: "Journal" },
    { key: "link", label: "Link" },
    { key: "status", label: "Status" },
    { key: "slides", label: "Slides" }
  ];

  const meetingColumns = [
    { key: "participant", label: "Participant name" },
    { key: "title", label: "Paper title" },
    { key: "authors", label: "Authors" },
    { key: "year", label: "Year" },
    { key: "journal", label: "Journal Name" },
    { key: "link", label: "Link to paper" },
    { key: "status", label: "Status" },
    { key: "slides", label: "Slides" }
  ];

  const archiveKey = "rrg_archive";
  let archiveRows = storage.get(archiveKey, []);

  const setLoading = (isLoading) => {
    archiveStatus.classList.toggle("is-loading", isLoading);
  };

  const setMeetingLoading = (isLoading) => {
    if (!meetingStatus) {
      return;
    }
    meetingStatus.classList.toggle("is-loading", isLoading);
  };

  const resolveNextMeeting = async () => {
    if (!isApiConfigured()) {
      return getCutoffMeetingDate();
    }
    try {
      const data = await fetchJson(apiUrl({ action: "nextMeeting" }));
      return data.meeting || getCutoffMeetingDate();
    } catch (error) {
      return getCutoffMeetingDate();
    }
  };

  const loadCurrentMeeting = async () => {
    if (!meetingTable || !meetingStatus || !meetingDateLabel) {
      return;
    }
    if (!isApiConfigured()) {
      setStatus(meetingStatus, "Set APPS_SCRIPT_URL in app.js to enable submissions.", true);
      return;
    }
    const fallbackMeeting = getCutoffMeetingDate();
    meetingDateLabel.textContent = formatReadableDate(fallbackMeeting);
    setMeetingLoading(true);
    try {
      const meeting = await resolveNextMeeting();
      meetingDateLabel.textContent = formatReadableDate(meeting);
      const data = await fetchJson(apiUrl({ action: "meeting", meeting }));
      renderTable(meetingTable, data.rows || [], meetingColumns, "No submissions yet.");
    } catch (error) {
      setStatus(meetingStatus, error.message, true);
    } finally {
      setMeetingLoading(false);
    }
  };

  const syncArchive = async () => {
    if (!isApiConfigured()) {
      setStatus(archiveStatus, "Set APPS_SCRIPT_URL in app.js to enable sync.", true);
      return;
    }
    try {
      setLoading(true);
      const data = await fetchJson(apiUrl({ action: "archive" }));
      archiveRows = data.rows || [];
      storage.set(archiveKey, archiveRows);
      renderArchive();
      const timestamp = new Date().toLocaleString();
      setStatus(archiveStatus, `Archive synced from admin sheet. Last synced ${timestamp}.`);
    } catch (error) {
      setStatus(archiveStatus, error.message, true);
    } finally {
      setLoading(false);
    }
  };

  const parseDateKey = (value) => {
    const parts = String(value || "").split("-").map((part) => Number.parseInt(part, 10));
    if (parts.length !== 3 || parts.some((part) => Number.isNaN(part))) {
      return null;
    }
    return new Date(parts[0], parts[1] - 1, parts[2]);
  };

  const buildMeetingGroups = (rows) => {
    const grouped = rows.reduce((acc, row) => {
      const meeting = row.meeting || "--";
      if (!acc[meeting]) {
        acc[meeting] = [];
      }
      acc[meeting].push(row);
      return acc;
    }, {});

    return Object.entries(grouped)
      .map(([meeting, meetingRows]) => ({ meeting, rows: meetingRows }))
      .sort((a, b) => {
        const dateA = parseDateKey(a.meeting);
        const dateB = parseDateKey(b.meeting);
        if (dateA && dateB) {
          return dateB - dateA;
        }
        return String(b.meeting).localeCompare(String(a.meeting));
      });
  };

  const renderArchive = () => {
    archiveAccordion.innerHTML = "";

    if (!archiveRows.length) {
      archiveAccordion.textContent = "No archive entries yet.";
      return;
    }

    const groups = buildMeetingGroups(archiveRows);
    groups.forEach((group, index) => {
      const details = document.createElement("details");
      details.classList.add("archive-group");
      if (index === 0) {
        details.open = true;
      }

      const summary = document.createElement("summary");
      summary.classList.add("archive-summary");

      const title = document.createElement("span");
      title.classList.add("archive-date");
      title.textContent = formatReadableDate(group.meeting);

      const approvedCount = group.rows.filter(
        (row) => String(row.status || "").toLowerCase() === "approved"
      ).length;
      const longCount = group.rows.filter(
        (row) => String(row.status || "").toLowerCase() === "long"
      ).length;
      const vetoedCount = group.rows.filter(
        (row) => String(row.status || "").toLowerCase() === "vetoed"
      ).length;
      const slidesCount = group.rows.filter(
        (row) => String(row.slides || "").startsWith("http")
      ).length;
      const summaryText =
        `${group.rows.length} submissions | ${approvedCount} approved | ${longCount} long | ` +
        `${vetoedCount} vetoed | ${slidesCount} slides`;
      const meta = document.createElement("span");
      meta.classList.add("archive-meta");
      meta.textContent = summaryText;

      summary.appendChild(title);
      summary.appendChild(meta);
      details.appendChild(summary);

      const tableWrap = document.createElement("div");
      tableWrap.classList.add("table-wrap");
      const table = document.createElement("table");
      tableWrap.appendChild(table);
      renderTable(table, group.rows, columns, "No submissions yet.");

      details.appendChild(tableWrap);
      archiveAccordion.appendChild(details);
    });
  };

  renderArchive();

  loadCurrentMeeting();

  syncArchive();

  syncButton.addEventListener("click", syncArchive);
};

const initHomePage = () => {
  const nextMeetingHome = document.getElementById("next-meeting-home");
  if (!nextMeetingHome) {
    return;
  }
  const meeting = getCutoffMeetingDate();
  nextMeetingHome.textContent = formatReadableDate(meeting);
};

const initAdminPage = () => {
  const adminForm = document.getElementById("admin-auth");
  const adminAuthSubmitButton = document.getElementById("admin-auth-submit");
  const adminKeyInput = document.getElementById("admin-key");
  const meetingInput = document.getElementById("admin-meeting");
  const loadButton = document.getElementById("admin-load");
  const emailNextButton = document.getElementById("admin-email-next");
  const downloadButton = document.getElementById("admin-download");
  const clearButton = document.getElementById("admin-clear");
  const table = document.getElementById("admin-table");
  const status = document.getElementById("admin-status");
  const updateForm = document.getElementById("admin-update");
  const allowlistForm = document.getElementById("admin-allowlist");
  const selectAllInput = document.getElementById("admin-select-all");
  const bulkStatusSelect = document.getElementById("admin-bulk-status");
  const bulkNoteInput = document.getElementById("admin-bulk-note");
  const bulkApplyButton = document.getElementById("admin-bulk-apply");
  const selectedCount = document.getElementById("admin-selected-count");
  const gatedSections = Array.from(document.querySelectorAll("[data-admin-gated]"));

  const columns = [
    { key: "participant", label: "Participant" },
    { key: "email", label: "Email" },
    { key: "title", label: "Paper" },
    { key: "authors", label: "Authors" },
    { key: "year", label: "Year" },
    { key: "link", label: "Link" },
    { key: "status", label: "Status" },
    { key: "slides", label: "Slides" }
  ];

  let meetingRows = [];
  let selectedEmails = new Set();
  let isAdminVerified = false;
  meetingInput.value = meetingInput.value || getCutoffMeetingDate();

  const setLoading = (isLoading) => {
    status.classList.toggle("is-loading", isLoading);
    if (adminAuthSubmitButton) {
      adminAuthSubmitButton.disabled = isLoading;
    }
  };

  const setGatedControlsEnabled = (enabled) => {
    gatedSections.forEach((section) => {
      section.classList.toggle("is-locked", !enabled);
      const controls = section.querySelectorAll("input, select, textarea, button");
      controls.forEach((control) => {
        control.disabled = !enabled;
      });
    });
    updateSelectedUi();
    renderAdminTable();
    updateAllowlistSelectedUi();
    renderAllowlistTable();
  };

  const updateSelectedUi = () => {
    const count = selectedEmails.size;
    selectedCount.textContent = `${count} selected`;
    bulkApplyButton.disabled = !isAdminVerified || count === 0;
    if (count === 0) {
      selectAllInput.checked = false;
    }
  };

  const renderAdminTable = () => {
    const thead = table.querySelector("thead") || table.createTHead();
    const tbody = table.querySelector("tbody") || table.createTBody();
    thead.innerHTML = "";
    tbody.innerHTML = "";

    const headerRow = document.createElement("tr");
    const selectTh = document.createElement("th");
    selectTh.classList.add("checkbox-cell");
    headerRow.appendChild(selectTh);
    columns.forEach((column) => {
      const th = document.createElement("th");
      th.textContent = column.label;
      headerRow.appendChild(th);
    });
    thead.appendChild(headerRow);

    if (meetingRows.length === 0) {
      const emptyRow = document.createElement("tr");
      const td = document.createElement("td");
      td.colSpan = columns.length + 1;
      td.textContent = "No submissions yet.";
      emptyRow.appendChild(td);
      tbody.appendChild(emptyRow);
      return;
    }

    meetingRows.forEach((row) => {
      const tr = document.createElement("tr");
      const selectTd = document.createElement("td");
      selectTd.classList.add("checkbox-cell");
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = selectedEmails.has(row.email);
      checkbox.disabled = !isAdminVerified;
      checkbox.addEventListener("change", () => {
        if (checkbox.checked) {
          selectedEmails.add(row.email);
        } else {
          selectedEmails.delete(row.email);
        }
        updateSelectedUi();
      });
      selectTd.appendChild(checkbox);
      tr.appendChild(selectTd);

      columns.forEach((column) => {
        const td = document.createElement("td");
        const value = row[column.key] || "";
        if (column.key === "slides") {
          if (value && value.startsWith("http")) {
            const anchor = document.createElement("a");
            anchor.href = value;
            anchor.textContent = "link";
            anchor.target = "_blank";
            anchor.rel = "noopener";
            td.appendChild(anchor);
          } else {
            td.textContent = "-";
          }
        } else if (column.key === "link" && value.startsWith("http")) {
          const anchor = document.createElement("a");
          anchor.href = value;
          anchor.textContent = value;
          anchor.target = "_blank";
          anchor.rel = "noopener";
          td.appendChild(anchor);
        } else {
          td.textContent = value;
        }
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
  };

  const allowlistTable = document.getElementById("allowlist-table");
  const allowlistSelectAllInput = document.getElementById("allowlist-select-all");
  const allowlistSelectedCount = document.getElementById("allowlist-selected-count");
  const allowlistRemoveButton = document.getElementById("allowlist-remove");
  let allowlistRows = [];
  let selectedAllowlistEmails = new Set();

  const updateAllowlistSelectedUi = () => {
    const count = selectedAllowlistEmails.size;
    if (allowlistSelectedCount) {
      allowlistSelectedCount.textContent = `${count} selected`;
    }
    if (allowlistRemoveButton) {
      allowlistRemoveButton.disabled = !isAdminVerified || count === 0;
    }
    if (count === 0 && allowlistSelectAllInput) {
      allowlistSelectAllInput.checked = false;
    }
  };

  const renderAllowlistTable = () => {
    const thead = allowlistTable.querySelector("thead") || allowlistTable.createTHead();
    const tbody = allowlistTable.querySelector("tbody") || allowlistTable.createTBody();
    thead.innerHTML = "";
    tbody.innerHTML = "";

    const headerRow = document.createElement("tr");
    const selectTh = document.createElement("th");
    selectTh.classList.add("checkbox-cell");
    headerRow.appendChild(selectTh);
    const thEmail = document.createElement("th");
    thEmail.textContent = "Email";
    const thAdded = document.createElement("th");
    thAdded.textContent = "Date Added";
    headerRow.appendChild(thEmail);
    headerRow.appendChild(thAdded);
    thead.appendChild(headerRow);

    if (allowlistRows.length === 0) {
      const emptyRow = document.createElement("tr");
      const td = document.createElement("td");
      td.colSpan = 3;
      td.textContent = "No emails in allowlist.";
      emptyRow.appendChild(td);
      tbody.appendChild(emptyRow);
      return;
    }

    allowlistRows.forEach((row) => {
      const tr = document.createElement("tr");
      
      const selectTd = document.createElement("td");
      selectTd.classList.add("checkbox-cell");
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = selectedAllowlistEmails.has(row.email);
      checkbox.disabled = !isAdminVerified;
      checkbox.addEventListener("change", () => {
        if (checkbox.checked) {
          selectedAllowlistEmails.add(row.email);
        } else {
          selectedAllowlistEmails.delete(row.email);
        }
        updateAllowlistSelectedUi();
      });
      selectTd.appendChild(checkbox);
      tr.appendChild(selectTd);
      
      const emailTd = document.createElement("td");
      emailTd.textContent = row.email || "";
      const dateTd = document.createElement("td");
      dateTd.textContent = row.date_added || "-";
      tr.appendChild(emailTd);
      tr.appendChild(dateTd);
      tbody.appendChild(tr);
    });
  };

  const loadAllowlist = async () => {
    if (!isApiConfigured()) {
      setStatus(status, "Set APPS_SCRIPT_URL in app.js to enable admin access.", true);
      return;
    }
    if (!isAdminVerified) {
      setStatus(status, "Submit a valid admin key to unlock controls.", true);
      return;
    }
    const adminKey = adminKeyInput.value.trim();
    if (!adminKey) {
      setStatus(status, "Admin key is required.", true);
      return;
    }
    setLoading(true);
    try {
      const data = await postApi({ action: "adminGetAllowlist", adminKey });
      allowlistRows = data.rows || [];
      selectedAllowlistEmails = new Set();
      renderAllowlistTable();
      updateAllowlistSelectedUi();
      setStatus(status, `Allowlist loaded (${allowlistRows.length} emails).`);
    } catch (error) {
      setStatus(status, error.message, true);
    } finally {
      setLoading(false);
    }
  };

  const allowlistLoadButton = document.getElementById("admin-allowlist-load");
  if (allowlistLoadButton) {
    allowlistLoadButton.addEventListener("click", (event) => {
      event.preventDefault();
      loadAllowlist().catch((error) => setStatus(status, error.message, true));
    });
  }

  if (allowlistSelectAllInput) {
    allowlistSelectAllInput.addEventListener("change", () => {
      if (allowlistSelectAllInput.checked) {
        const allEmails = allowlistRows.map((row) => row.email).filter(Boolean);
        selectedAllowlistEmails = new Set(allEmails);
      } else {
        selectedAllowlistEmails = new Set();
      }
      updateAllowlistSelectedUi();
      renderAllowlistTable();
    });
  }

  if (allowlistRemoveButton) {
    allowlistRemoveButton.addEventListener("click", async () => {
      const adminKey = adminKeyInput.value.trim();
      if (!adminKey) {
        setStatus(status, "Admin key is required.", true);
        return;
      }
      const emails = Array.from(selectedAllowlistEmails);
      if (!emails.length) {
        setStatus(status, "Select at least one email to remove.", true);
        return;
      }
      
      const confirmed = window.confirm(
        `Remove ${emails.length} email(s) from the allowlist?\n\n${emails.join("\n")}`
      );
      if (!confirmed) {
        return;
      }
      
      try {
        setLoading(true);
        const data = await postApi({
          action: "adminRemoveAllowlist",
          adminKey,
          emails: JSON.stringify(emails)
        });
        selectedAllowlistEmails = new Set();
        await loadAllowlist();
        setStatus(status, `Removed ${data.removed || 0} email(s) from allowlist.`);
      } catch (error) {
        setStatus(status, error.message, true);
      } finally {
        setLoading(false);
      }
    });
  }

  const loadMeeting = async () => {
    if (!isApiConfigured()) {
      setStatus(status, "Set APPS_SCRIPT_URL in app.js to enable admin access.", true);
      return;
    }
    if (!isAdminVerified) {
      setStatus(status, "Submit a valid admin key to unlock controls.", true);
      return;
    }
    const adminKey = adminKeyInput.value.trim();
    if (!adminKey) {
      setStatus(status, "Admin key is required.", true);
      return;
    }
    setLoading(true);
    try {
      const meeting = meetingInput.value;
      const data = await postApi({ action: "adminList", meeting, adminKey });
      meetingRows = data.rows || [];
      selectedEmails = new Set();
      selectAllInput.checked = false;
      updateSelectedUi();
      renderAdminTable();
      setStatus(status, "Admin submissions loaded.");
    } finally {
      setLoading(false);
    }
  };

  const verifyAdminKey = async () => {
    if (!isApiConfigured()) {
      setStatus(status, "Set APPS_SCRIPT_URL in app.js to enable admin access.", true);
      return;
    }
    const adminKey = adminKeyInput.value.trim();
    if (!adminKey) {
      setStatus(status, "Admin key is required.", true);
      return;
    }

    try {
      setLoading(true);
      await postApi({ action: "adminList", meeting: "", adminKey });
      isAdminVerified = true;
      window.sessionStorage.setItem(CONFIG.ADMIN_KEY_STORAGE, adminKey);
      setGatedControlsEnabled(true);
      setStatus(status, "Admin key accepted. Controls unlocked.");
      try {
        await loadMeeting();
      } catch (error) {
        setStatus(status, error.message, true);
      }
      try {
        await loadAllowlist();
      } catch (error) {
        setStatus(status, error.message, true);
      }
    } catch (error) {
      isAdminVerified = false;
      setGatedControlsEnabled(false);
      setStatus(status, error.message, true);
    } finally {
      setLoading(false);
    }
  };

  const cachedKey = window.sessionStorage.getItem(CONFIG.ADMIN_KEY_STORAGE);
  if (cachedKey) {
    adminKeyInput.value = cachedKey;
  }
  setGatedControlsEnabled(false);
  setStatus(status, "Submit your admin key to unlock controls.");
  updateSelectedUi();
  renderAdminTable();

  adminForm.addEventListener("submit", (event) => {
    event.preventDefault();
    verifyAdminKey().catch((error) => setStatus(status, error.message, true));
  });

  adminKeyInput.addEventListener("input", () => {
    if (!isAdminVerified) {
      return;
    }
    isAdminVerified = false;
    selectedEmails = new Set();
    setGatedControlsEnabled(false);
    setStatus(status, "Admin key changed. Submit again to unlock controls.");
  });

  downloadButton.addEventListener("click", () => {
    if (!meetingRows.length) {
      setStatus(status, "No submissions to export.", true);
      return;
    }
    downloadCsv(`rrg_${meetingInput.value}.csv`, meetingRows, MEETING_COLUMNS);
    setStatus(status, "Meeting CSV downloaded.");
  });

  if (updateForm) {
    updateForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(updateForm);
      const email = formData.get("email")?.trim() || "";
      const participant = formData.get("participant")?.trim() || "";
      const statusValue = formData.get("status")?.trim() || "pending";
      const adminNote = formData.get("admin_note")?.trim() || "";
      const adminKey = adminKeyInput.value.trim();

      if (!email) {
        setStatus(status, "Email is required to update a submission.", true);
        return;
      }

      try {
        setLoading(true);
        await postApi({
          action: "adminUpdate",
          adminKey,
          meeting: meetingInput.value,
          email,
          participant,
          status: statusValue,
          admin_note: adminNote
        });
        updateForm.reset();
        await loadMeeting();
        setStatus(status, "Submission updated.");
      } catch (error) {
        setStatus(status, error.message, true);
      } finally {
        setLoading(false);
      }
    });
  }

  if (allowlistForm) {
    allowlistForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(allowlistForm);
      const email = formData.get("email")?.trim() || "";
      const adminKey = adminKeyInput.value.trim();

      if (!adminKey) {
        setStatus(status, "Admin key is required.", true);
        return;
      }
      if (!email) {
        setStatus(status, "Email is required.", true);
        return;
      }

      try {
        setStatus(status, `Adding ${email}…`);
        setLoading(true);
        const data = await postApi({
          action: "adminAddAllowlist",
          adminKey,
          email
        });
        allowlistForm.reset();
        const added = Array.isArray(data.added) ? data.added : [];
        if (added.includes(email.toLowerCase())) {
          setStatus(status, `Added ${email} to allowlist.`);
        } else {
          setStatus(status, `${email} is already in allowlist.`);
        }
        // Refresh the allowlist if it's been loaded
        if (allowlistRows.length > 0) {
          await loadAllowlist();
        }
      } catch (error) {
        setStatus(status, error.message, true);
      } finally {
        setLoading(false);
      }
    });
  }

  loadButton.addEventListener("click", (event) => {
    event.preventDefault();
    loadMeeting().catch((error) => setStatus(status, error.message, true));
  });

  if (emailNextButton) {
    emailNextButton.addEventListener("click", async () => {
      const adminKey = adminKeyInput.value.trim();
      const meetingDate = meetingInput.value;
      if (!isApiConfigured()) {
        setStatus(status, "Set APPS_SCRIPT_URL in app.js to enable admin access.", true);
        return;
      }
      if (!adminKey) {
        setStatus(status, "Admin key is required.", true);
        return;
      }
      if (!meetingDate) {
        setStatus(status, "Meeting date is required.", true);
        return;
      }
      try {
        setLoading(true);
        const submitterData = await postApi({ action: "adminList", meeting: meetingDate, adminKey });
        const submitterMap = new Map();
        (submitterData.rows || []).forEach((row) => {
          const email = String(row.email || "").trim();
          if (!email) {
            return;
          }
          if (!submitterMap.has(email)) {
            const participant = String(row.participant || "").trim() || "Unknown";
            submitterMap.set(email, participant);
          }
        });

        const submitterLines = Array.from(submitterMap.entries())
          .map(([email, participant]) => `${participant} (${email})`)
          .sort((left, right) => left.localeCompare(right));

        if (!submitterLines.length) {
          setStatus(status, `No submitters found for ${meetingDate}.`, true);
          return;
        }

        const confirmationMessage = [
          "Send meeting email?",
          "",
          `Meeting: ${formatReadableDate(meetingDate)} (${meetingDate})`,
          `Submitters (${submitterLines.length}):`,
          ...submitterLines
        ].join("\n");

        const confirmed = window.confirm(confirmationMessage);
        if (!confirmed) {
          setStatus(status, "Cancelled meeting email.");
          return;
        }

        const data = await postApi({ action: "adminEmailNextMeetingSubmitters", adminKey, meeting: meetingDate });
        const sentCount = Number(data.sent || 0);
        const ccCount = Number(data.ccCount || 0);
        const sentMeetingDate = data.meeting || meetingDate;
        setStatus(status, `Sent ${sentCount} email to froldan@nyu.edu with ${ccCount} submitter(s) in CC for ${sentMeetingDate}.`);
      } catch (error) {
        setStatus(status, error.message, true);
      } finally {
        setLoading(false);
      }
    });
  }

  clearButton.addEventListener("click", async () => {
    const adminKey = adminKeyInput.value.trim();
    if (!adminKey) {
      setStatus(status, "Admin key is required.", true);
      return;
    }
    const confirmed = window.confirm(
      "This will remove all rows from the submissions sheet. Are you sure you want to continue?"
    );
    if (!confirmed) {
      return;
    }
    try {
      setLoading(true);
      const data = await postApi({ action: "adminClearSubmissions", adminKey });
      meetingRows = [];
      selectedEmails = new Set();
      selectAllInput.checked = false;
      updateSelectedUi();
      renderAdminTable();
      setStatus(status, `Cleared ${data.cleared || 0} submissions.`);
    } catch (error) {
      setStatus(status, error.message, true);
    } finally {
      setLoading(false);
    }
  });

  selectAllInput.addEventListener("change", () => {
    if (selectAllInput.checked) {
      const pendingEmails = meetingRows
        .filter((row) => String(row.status || "").toLowerCase() === "pending")
        .map((row) => row.email)
        .filter(Boolean);
      selectedEmails = new Set(pendingEmails);
    } else {
      selectedEmails = new Set();
    }
    updateSelectedUi();
    renderAdminTable();
  });

  bulkApplyButton.addEventListener("click", async () => {
    const adminKey = adminKeyInput.value.trim();
    if (!adminKey) {
      setStatus(status, "Admin key is required.", true);
      return;
    }
    const emails = Array.from(selectedEmails);
    if (!emails.length) {
      setStatus(status, "Select at least one submission.", true);
      return;
    }
    try {
      setLoading(true);
      const data = await postApi({
        action: "adminBulkUpdate",
        adminKey,
        meeting: meetingInput.value,
        status: bulkStatusSelect.value,
        admin_note: bulkNoteInput.value.trim(),
        emails: JSON.stringify(emails)
      });
      bulkStatusSelect.value = "approved";
      bulkNoteInput.value = "";
      selectedEmails = new Set();
      selectAllInput.checked = false;
      updateSelectedUi();
      await loadMeeting();
      setStatus(status, `Updated ${data.updated || 0} submissions.`);
    } catch (error) {
      setStatus(status, error.message, true);
    } finally {
      setLoading(false);
    }
  });
};

const page = document.body.dataset.page;
initThemeToggle();
if (page === "submission") {
  initSubmissionPage();
}
if (page === "archive") {
  initArchivePage();
}
if (page === "admin") {
  initAdminPage();
}
if (page === "home") {
  initHomePage();
}
