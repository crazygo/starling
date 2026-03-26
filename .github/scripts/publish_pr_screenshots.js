const fs = require('fs');
const path = require('path');

const SCREENSHOT_DIR = 'screenshots';
const COMMENT_MARKER = '<!-- pr-screenshot-bot -->';
const PREVIEW_BRANCH = 'pr-screenshot-previews';
const PREVIEW_ROOT = '.github/pr-screenshots';
const LABELS = {
  home: '首页',
  explore: '巡天',
  settings: '设置',
};

const token = process.env.GITHUB_TOKEN;
const repository = process.env.GITHUB_REPOSITORY;
const runId = process.env.GITHUB_RUN_ID;
const sha = process.env.GITHUB_SHA;
const prNumber = process.env.PR_NUMBER;
const prHeadRef = process.env.PR_HEAD_REF;

if (!token) {
  throw new Error('GITHUB_TOKEN is required.');
}

if (!repository || !prNumber || !runId || !prHeadRef || !sha) {
  throw new Error('Missing one or more required GitHub environment variables.');
}

const [owner, repo] = repository.split('/');

if (!owner || !repo) {
  throw new Error(`Invalid GITHUB_REPOSITORY value: ${repository}`);
}

const previewDir = `${PREVIEW_ROOT}/pr-${prNumber}`;

function getScreenshotFiles() {
  if (!fs.existsSync(SCREENSHOT_DIR)) {
    throw new Error(`Screenshot directory not found: ${SCREENSHOT_DIR}`);
  }

  const files = fs
    .readdirSync(SCREENSHOT_DIR)
    .filter((file) => file.endsWith('.png'))
    .sort();

  if (files.length === 0) {
    throw new Error('No screenshot PNG files were generated.');
  }

  return files;
}

function previewImageUrl(fileName) {
  const encodedPath = `${previewDir}/${fileName}`
    .split('/')
    .map(encodeURIComponent)
    .join('/');
  return `https://raw.githubusercontent.com/${owner}/${repo}/${PREVIEW_BRANCH}/${encodedPath}?v=${encodeURIComponent(runId)}`;
}

function humanizeFileName(fileName) {
  const name = path.basename(fileName, '.png');
  return LABELS[name] || name;
}

async function githubRequest(apiPath, options = {}) {
  const response = await fetch(`https://api.github.com${apiPath}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'starling-pr-screenshot-bot',
      ...(options.headers || {}),
    },
  });

  if (response.status === 204) {
    return null;
  }

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const error = new Error(`GitHub API ${options.method || 'GET'} ${apiPath} failed: ${response.status}`);
    error.response = data;
    throw error;
  }

  return data;
}

async function ensurePreviewBranch() {
  try {
    await githubRequest(`/repos/${owner}/${repo}/git/ref/heads/${PREVIEW_BRANCH}`);
  } catch (error) {
    if (error.response?.message !== 'Not Found') {
      throw error;
    }

    const repoInfo = await githubRequest(`/repos/${owner}/${repo}`);
    const defaultRef = await githubRequest(
      `/repos/${owner}/${repo}/git/ref/heads/${encodeURIComponent(repoInfo.default_branch)}`,
    );

    await githubRequest(`/repos/${owner}/${repo}/git/refs`, {
      method: 'POST',
      body: JSON.stringify({
        ref: `refs/heads/${PREVIEW_BRANCH}`,
        sha: defaultRef.object.sha,
      }),
    });
  }
}

async function listRemotePreviewFiles() {
  try {
    const data = await githubRequest(
      `/repos/${owner}/${repo}/contents/${previewDir
        .split('/')
        .map(encodeURIComponent)
        .join('/')}?ref=${encodeURIComponent(PREVIEW_BRANCH)}`,
    );
    return Array.isArray(data) ? data.filter((entry) => entry.type === 'file') : [];
  } catch (error) {
    if (error.response?.message === 'Not Found') {
      return [];
    }
    throw error;
  }
}

async function upsertPreviewFile(fileName, existingSha) {
  const content = fs.readFileSync(path.join(SCREENSHOT_DIR, fileName)).toString('base64');
  const encodedPath = `${previewDir}/${fileName}`
    .split('/')
    .map(encodeURIComponent)
    .join('/');

  await githubRequest(`/repos/${owner}/${repo}/contents/${encodedPath}`, {
    method: 'PUT',
    body: JSON.stringify({
      message: `chore: update screenshot preview for PR #${prNumber}`,
      branch: PREVIEW_BRANCH,
      content,
      sha: existingSha,
    }),
  });
}

async function deletePreviewFile(fileName, existingSha) {
  const encodedPath = `${previewDir}/${fileName}`
    .split('/')
    .map(encodeURIComponent)
    .join('/');

  await githubRequest(`/repos/${owner}/${repo}/contents/${encodedPath}`, {
    method: 'DELETE',
    body: JSON.stringify({
      message: `chore: remove stale screenshot preview for PR #${prNumber}`,
      branch: PREVIEW_BRANCH,
      sha: existingSha,
    }),
  });
}

async function syncPreviewFiles(files) {
  const remoteFiles = await listRemotePreviewFiles();
  const remoteByName = new Map(remoteFiles.map((file) => [file.name, file]));
  const localNames = new Set(files);

  for (const fileName of files) {
    await upsertPreviewFile(fileName, remoteByName.get(fileName)?.sha);
  }

  for (const remoteFile of remoteFiles) {
    if (!localNames.has(remoteFile.name) && remoteFile.name.endsWith('.png')) {
      await deletePreviewFile(remoteFile.name, remoteFile.sha);
    }
  }
}

async function upsertPrComment(body) {
  let existing = null;
  let page = 1;

  while (!existing) {
    const comments = await githubRequest(
      `/repos/${owner}/${repo}/issues/${prNumber}/comments?per_page=100&page=${page}`,
    );

    if (!comments.length) {
      break;
    }

    existing = comments.find((comment) => comment.body?.includes(COMMENT_MARKER));
    page += 1;
  }

  if (existing) {
    await githubRequest(`/repos/${owner}/${repo}/issues/comments/${existing.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ body }),
    });
    return;
  }

  await githubRequest(`/repos/${owner}/${repo}/issues/${prNumber}/comments`, {
    method: 'POST',
    body: JSON.stringify({ body }),
  });
}

function buildCommentBody(files) {
  const artifactUrl = `https://github.com/${owner}/${repo}/actions/runs/${runId}`;
  const lines = [
    '## 📸 自动化截图预览',
    '',
    `构建时间：${new Date().toISOString().replace('T', ' ').slice(0, 19)} UTC`,
    `分支：\`${prHeadRef}\``,
    `提交：\`${sha.slice(0, 7)}\``,
    '',
    '以下为本次工作流生成的最新截图：',
    '',
  ];

  for (const fileName of files) {
    const label = humanizeFileName(fileName);
    lines.push(`### ${label}`);
    lines.push(
      `<img src="${previewImageUrl(fileName)}" alt="${label}" width="240" />`,
    );
    lines.push('');
  }

  lines.push(`👉 [下载完整截图 Artifact](${artifactUrl})`);
  lines.push('');
  lines.push(COMMENT_MARKER);
  return lines.join('\n');
}

async function main() {
  const files = getScreenshotFiles();
  await ensurePreviewBranch();
  await syncPreviewFiles(files);
  await upsertPrComment(buildCommentBody(files));
}

main().catch((error) => {
  console.error(error);
  if (error.response) {
    console.error(JSON.stringify(error.response, null, 2));
  }
  process.exit(1);
});
