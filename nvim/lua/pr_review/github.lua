-- GitHub side of the pull request review (pr_review/init.lua). Every call goes through `gh api graphql`,
-- so authentication and the host are whatever the `gh` CLI is logged in to.
local M = {}

local PULL_REQUEST = [[
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id number title url state isDraft
      baseRefName headRefName baseRefOid headRefOid
      author { login }
      reviews(states: PENDING, first: 10) { nodes { id viewerDidAuthor } }
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated path line startLine diffSide
          viewerCanResolve viewerCanUnresolve viewerCanReply
          comments(first: 100) {
            nodes {
              id body createdAt url state viewerDidAuthor viewerCanUpdate viewerCanDelete
              author { login }
            }
          }
        }
      }
    }
  }
}]]

--- Runs one GraphQL request. `done(err, data)` is called on the main loop.
local function graphql(query, variables, done)
  local body = vim.json.encode({ query = query, variables = variables })
  local ok, err = pcall(vim.system, { "gh", "api", "graphql", "--input", "-" }, { stdin = body, text = true }, function(out)
    vim.schedule(function()
      local decoded_ok, decoded = pcall(vim.json.decode, out.stdout or "", { luanil = { object = true, array = true } })
      if decoded_ok and type(decoded) == "table" and decoded.errors then
        local messages = vim.tbl_map(function(it)
          return it.message
        end, decoded.errors)
        return done(table.concat(messages, "\n"))
      end
      if out.code ~= 0 or not decoded_ok or type(decoded) ~= "table" or not decoded.data then
        return done(vim.trim(out.stderr or "") ~= "" and vim.trim(out.stderr) or "GitHub did not answer (gh exit code " .. out.code .. ")")
      end
      done(nil, decoded.data)
    end)
  end)
  if not ok then
    done("Could not run the gh CLI: " .. tostring(err))
  end
end

local function mutate(name, input_type, input, selection, done)
  local query = ("mutation($input: %s!) { %s(input: $input) { %s } }"):format(input_type, name, selection)
  graphql(query, { input = input }, function(err, data)
    done(err, data and data[name])
  end)
end

local function to_comment(node)
  return {
    id = node.id,
    author = node.author and node.author.login or "ghost",
    body = (node.body or ""):gsub("\r", ""),
    created_at = node.createdAt,
    url = node.url,
    pending = node.state == "PENDING",
    mine = node.viewerDidAuthor == true,
    can_update = node.viewerCanUpdate == true,
    can_delete = node.viewerCanDelete == true,
  }
end

local function to_thread(node)
  local comments = vim.tbl_map(to_comment, node.comments.nodes)
  return {
    id = node.id,
    path = node.path,
    -- an outdated thread has no line: the code it was written on is no longer part of the diff
    line = node.line,
    start_line = node.startLine or node.line,
    side = node.diffSide,
    resolved = node.isResolved == true,
    outdated = node.isOutdated == true or node.line == nil,
    can_resolve = node.viewerCanResolve == true,
    can_unresolve = node.viewerCanUnresolve == true,
    can_reply = node.viewerCanReply == true,
    comments = comments,
    -- a thread that only exists in the viewer's unsubmitted review
    pending = comments[1] ~= nil and comments[1].pending,
  }
end

--- Loads a pull request with all its review threads.
function M.pull_request(owner, name, number, done)
  local threads = {}
  local function page(cursor)
    graphql(PULL_REQUEST, { owner = owner, name = name, number = number, cursor = cursor }, function(err, data)
      local node = data and data.repository and data.repository.pullRequest
      if err or not node then
        return done(err or ("Pull request #%d not found in %s/%s"):format(number, owner, name))
      end
      for _, thread in ipairs(node.reviewThreads.nodes) do
        if #thread.comments.nodes > 0 then
          table.insert(threads, to_thread(thread))
        end
      end
      if node.reviewThreads.pageInfo.hasNextPage then
        return page(node.reviewThreads.pageInfo.endCursor)
      end
      local pending_review
      for _, review in ipairs(node.reviews.nodes) do
        pending_review = review.viewerDidAuthor and review.id or pending_review
      end
      done(nil, {
        owner = owner,
        name = name,
        id = node.id,
        number = node.number,
        title = node.title,
        url = node.url,
        state = node.state,
        draft = node.isDraft == true,
        author = node.author and node.author.login or "ghost",
        base_ref = node.baseRefName,
        head_ref = node.headRefName,
        base_oid = node.baseRefOid,
        head_oid = node.headRefOid,
        viewer = data.viewer.login,
        pending_review_id = pending_review,
        threads = threads,
      })
    end)
  end
  page(nil)
end

--- The pull request of the checked out branch (or `number` in this repository): `done(err, owner, name, number)`.
function M.locate(number, done)
  local args = { "gh", "pr", "view" }
  if number then
    table.insert(args, tostring(number))
  end
  vim.list_extend(args, { "--json", "url" })
  vim.system(args, { text = true }, function(out)
    vim.schedule(function()
      local ok, decoded = pcall(vim.json.decode, out.stdout or "")
      local owner, name, found = (ok and type(decoded) == "table" and decoded.url or ""):match("^https?://[^/]+/([^/]+)/([^/]+)/pull/(%d+)")
      if out.code ~= 0 or not owner then
        return done(number and ("Pull request #%s not found"):format(number) or "No pull request for the current branch")
      end
      done(nil, owner, name, tonumber(found))
    end)
  end)
end

--- Adds a comment on `range.line` (or `range.start_line` to `range.line`) of one side of the diff. GitHub
--- puts it into the viewer's pending review and creates that review when there is none.
function M.add_thread(pr, range, body, done)
  local multiline = range.start_line ~= range.line
  mutate("addPullRequestReviewThread", "AddPullRequestReviewThreadInput", {
    pullRequestId = pr.id,
    path = range.path,
    side = range.side,
    line = range.line,
    startSide = multiline and range.side or nil,
    startLine = multiline and range.start_line or nil,
    body = body,
  }, "thread { id }", function(err, result)
    -- GitHub answers 200 with an empty thread when the line is not part of the diff
    done(err or (not (result and result.thread) and "GitHub did not accept a comment on this line") or nil)
  end)
end

--- Replies in a thread: part of the pending review when there is one, posted at once otherwise.
function M.reply(thread, body, done)
  mutate("addPullRequestReviewThreadReply", "AddPullRequestReviewThreadReplyInput", {
    pullRequestReviewThreadId = thread.id,
    body = body,
  }, "comment { id }", done)
end

function M.set_resolved(thread, resolved, done)
  local name = resolved and "resolveReviewThread" or "unresolveReviewThread"
  local input_type = resolved and "ResolveReviewThreadInput" or "UnresolveReviewThreadInput"
  mutate(name, input_type, { threadId = thread.id }, "thread { id isResolved }", done)
end

function M.update_comment(comment, body, done)
  mutate("updatePullRequestReviewComment", "UpdatePullRequestReviewCommentInput", {
    pullRequestReviewCommentId = comment.id,
    body = body,
  }, "pullRequestReviewComment { id }", done)
end

function M.delete_comment(comment, done)
  mutate("deletePullRequestReviewComment", "DeletePullRequestReviewCommentInput", { id = comment.id }, "pullRequestReviewComment { id }", done)
end

--- Submits the pending review, or a new one without line comments. `event`: APPROVE, COMMENT or REQUEST_CHANGES.
function M.submit(pr, event, body, done)
  local text = body ~= "" and body or nil
  if pr.pending_review_id then
    mutate("submitPullRequestReview", "SubmitPullRequestReviewInput", {
      pullRequestReviewId = pr.pending_review_id,
      event = event,
      body = text,
    }, "pullRequestReview { id state }", done)
  else
    mutate("addPullRequestReview", "AddPullRequestReviewInput", {
      pullRequestId = pr.id,
      event = event,
      body = text,
    }, "pullRequestReview { id state }", done)
  end
end

--- Deletes the pending review with all its unsubmitted comments.
function M.discard(pr, done)
  mutate("deletePullRequestReview", "DeletePullRequestReviewInput", { pullRequestReviewId = pr.pending_review_id }, "pullRequestReview { id }", done)
end

return M
