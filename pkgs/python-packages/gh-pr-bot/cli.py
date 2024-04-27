import click

from github import Github  # type: ignore
from ghapi.all import GhApi  # type: ignore
from ghapi.page import paged  # type: ignore
from fastcore.net import HTTP404NotFoundError, HTTP422UnprocessableEntityError  # type: ignore

from base64 import b64decode
import logging
import re
import os

from ast import Num
from enum import Enum
import re
import yaml
import string
import logging
from typing import List

logger = logging.getLogger(__name__)

_GHE_HOST = os.environ.get("GHE_HOST")
_ACCESS_TOKENS = {
    "github.com": os.environ.get("GITHUB_TOKEN"),
}
_PR_AUTHOR_NAME = os.environ.get("PR_AUTHOR_NAME")
_PR_AUTHOR_EMAIL = os.environ.get("PR_AUTHOR_EMAIL")
_DEFAULT_PR_AUTHOR_NAME = "goromal"
_DEFAULT_PR_AUTHOR_EMAIL = "goromal.bot@gmail.com"


_REPO_SPLIT = re.compile(
    r"""
    ^(?:(\w+://)?        # Capture ssh:// or similar.
      (?:git@)?          # Capture 'git@'.
      (?P<server>[^/]+)/ # Grab the server URL.
     )?                  # The above are optional; default to _GHE_HOST.
     (?P<owner>[^/]+)/   # Grab the "owner" aka "organization".
     (?P<repo>[^/]+?)    # Finally, the repo name (non-greedily).
     (?:(?:\.git|/))?$   # ...and if it ends in '.git' or a trailing slash we don't care; toss it.
    """,
    re.VERBOSE,
)  # VERBOSE to allow those comments and arbitrary spacing above.

def isValidReleaseBranch(branch):
    return branch == "master"

ChangeType = Enum("ChangeType", "MAJOR MINOR BUGFIX CHORE _invalid", module=__name__)

CHANGE_TYPES = {
    "chore": ChangeType.CHORE,
    "bugfix": ChangeType.BUGFIX,
    "minor": ChangeType.MINOR,
    "major": ChangeType.MAJOR,
}

_CHANGE_TYPES_STR = {
    ChangeType.CHORE: "chore",
    ChangeType.BUGFIX: "bugfix",
    ChangeType.MINOR: "minor",
    ChangeType.MAJOR: "major",
}

class Repo:
    def __init__(self, repo, limit_cb=None, **extra_args):
        matches = _REPO_SPLIT.match(repo)
        if not matches:
            raise Exception(
                f"'{repo}' does not seem to be a valid repo specification."
            )
        ghe_host = _GHE_HOST if _GHE_HOST else "ghe.dev"
        logger.debug(ghe_host)
        server = matches.group("server") or ghe_host
        owner = matches.group("owner")
        self.name = matches.group("repo")
        if server == "github.com":
            host = "https://api.github.com"
            self.url = f"https://github.com/{owner}/{self.name}"
        else:
            host = f"https://{server}/api/v3"
            self.url = f"https://{server}/{owner}/{self.name}"
        token = _ACCESS_TOKENS.get(server)
        logger.debug(
            "Requested repo %s has server: %s, (host: %s), owner: %s, repo: %s",
            repo,
            server,
            host,
            owner,
            self.name,
        )
        logger.debug("Caching repo URL as %s", self.url)
        self.api = GhApi(gh_host=host, token=token, limit_cb=limit_cb)
        self.pygithub = Github(base_url=host, login_or_token=token)
        self.org_repo_name = repo
        self.kwargs = {
            "owner": owner,
            "repo": self.name,
        }
        self.kwargs.update(extra_args)
        if _PR_AUTHOR_NAME is None or _PR_AUTHOR_EMAIL is None:
            self.pr_author_name = _DEFAULT_PR_AUTHOR_NAME
            self.pr_author_email = _DEFAULT_PR_AUTHOR_EMAIL
        else:
            self.pr_author_name = _PR_AUTHOR_NAME
            self.pr_author_email = _PR_AUTHOR_EMAIL

    def getHead(self, ref="heads/master"):
        try:
            return self.api.git.get_ref(**self.kwargs, ref=ref)
        except HTTP404NotFoundError:
            logger.debug(
                "404 looking for head ref in %s/%s:%s.",
                self.kwargs["owner"],
                self.kwargs["repo"],
                ref,
            )
            return None

    def getCommit(self, sha: str, branch: str):
        commits = self.getCommits(sha=branch)
        if commits:
            for commit in commits:
                if sha in commit.sha:
                    return commit
        return None

    def getCommits(self, sha="heads/master"):
        try:
            result = []
            for page in paged(self.api.repos.list_commits, **self.kwargs, sha=sha):
                result.extend(page)
            return result
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting commits for sha=%s in %s/%s.",
                sha,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def getBranch(self, branch="master"):
        try:
            return self.api.repos.get_branch(**self.kwargs, branch=branch)
        except HTTP404NotFoundError:
            logger.debug(
                "404 looking for branch ref in %s/%s:%s.",
                self.kwargs["owner"],
                self.kwargs["repo"],
                branch,
            )
            return None

    def createBranch(self, branch, sha):
        return self.createRef("refs/heads/" + branch, sha=sha)

    def deleteBranch(self, branch):
        return self.deleteRef("heads/" + branch)

    def deleteRef(self, ref):
        try:
            return self.api.git.delete_ref(**self.kwargs, ref=ref)
        except HTTP422UnprocessableEntityError:
            logger.debug("422 attempting to delete a reference, name: %s.", ref)
            return None
        except HTTP404NotFoundError:
            logger.debug("404 attempting to delete a reference, name: %s.", ref)
            return None

    def getAllBranches(self):
        return self.api.repos.list_branches(**self.kwargs)

    def getDefaultBranch(self):
        try:
            response = self.api.repos.get(**self.kwargs)
            return response.default_branch
        except HTTP404NotFoundError:
            raise Exception(
                "404 cannot find repo %s/%s.",
                self.kwargs["owner"],
                self.kwargs["repo"],
            )

    def getPr(self, id):
        try:
            return self.api.pulls.get(**self.kwargs, pull_number=id)
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting PR #%s in %s/%s.",
                id,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def getPrFiles(self, id):
        try:
            result = []
            for page in paged(self.api.pulls.list_files, **self.kwargs, pull_number=id):
                result.extend(page)
            return result
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting files for PR #%s in %s/%s.",
                id,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def getFileList(self, path, ref="master"):
        try:
            return self.api.repos.get_content(**self.kwargs, path=path, ref=ref)
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting a file listing for %s in %s/%s:%s.",
                path,
                self.kwargs["owner"],
                self.kwargs["repo"],
                ref,
            )
            return None

    def getDiffList(self, basehead):
        try:
            return self.api.repos.compare_commits(**self.kwargs, basehead=basehead)
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting a diff listing in %s/%s basehead:%s.",
                self.kwargs["owner"],
                self.kwargs["repo"],
                basehead,
            )
            return None

    def getFileContent(self, filename, ref="master"):
        try:
            result = self.api.repos.get_content(**self.kwargs, path=filename, ref=ref)
            return b64decode(result.content).decode("utf-8")
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting file contents for %s in %s/%s:%s.",
                filename,
                self.kwargs["owner"],
                self.kwargs["repo"],
                ref,
            )
            return None

    def getCurrentAccountId(self):
        try:
            return self.api.users.get_authenticated().id
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting current user's ID in %s/%s.",
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def getRobotAccountId(self):
        try:
            return self.api.users.get_by_username("github-actions[bot]").id
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting robot ID in %s/%s.",
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def getIssueComments(self, issue_id):
        try:
            result = []
            for page in paged(
                self.api.issues.list_comments, **self.kwargs, issue_number=issue_id
            ):
                result.extend(page)
            return result
        except HTTP404NotFoundError:
            logger.debug(
                "404 getting comments from issue %s in %s/%s.",
                issue_id,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def createIssueComment(self, issue_id, body):
        try:
            return self.api.issues.create_comment(
                **self.kwargs, issue_number=issue_id, body=body
            )
        except HTTP404NotFoundError:
            logger.debug(
                "404 creating comment on issue %s in %s/%s.",
                issue_id,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def updateIssueComment(self, comment_id, body):
        try:
            return self.api.issues.update_comment(
                **self.kwargs, comment_id=comment_id, body=body
            )
        except HTTP404NotFoundError:
            logger.debug(
                "404 trying to update comment %s in %s/%s.",
                comment_id,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def deleteIssueComment(self, comment_id):
        try:
            return self.api.issues.delete_comment(**self.kwargs, comment_id=comment_id)
        except HTTP404NotFoundError:
            logger.debug(
                "404 attempting to delete comment %s in %s/%s.",
                comment_id,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def createGitBlob(self, content: str):
        try:
            return self.api.git.create_blob(**self.kwargs, content=content)
        except HTTP404NotFoundError:
            logger.debug(
                "404 attempting to create blob in %s/%s.",
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def getGitTree(self, tree_sha: str):
        try:
            return self.api.git.get_tree(**self.kwargs, tree_sha=tree_sha)
        except HTTP404NotFoundError:
            logger.debug(
                "404 attempting to get tree, sha: %s in %s/%s.",
                tree_sha,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def createGitTree(self, tree_sha: str, tree: list[dict]):
        try:
            return self.api.git.create_tree(
                **self.kwargs, base_tree=tree_sha, tree=tree
            )
        except HTTP404NotFoundError:
            logger.debug(
                "404 attempting to create tree, sha: %s in %s/%s.",
                tree_sha,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def createCommit(
        self, message: str, tree_sha: str, parents: list[str], author: dict
    ):
        try:
            return self.api.git.create_commit(
                **self.kwargs,
                message=message,
                author=author,
                parents=parents,
                tree=tree_sha,
            )
        except HTTP422UnprocessableEntityError:
            logger.debug(
                "422 attempting to create commit, sha: %s, parents %s in %s/%s.",
                tree_sha,
                parents,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def updateRef(self, ref: str, sha: str, force=False):
        try:
            return self.api.git.update_ref(**self.kwargs, ref=ref, sha=sha, force=force)
        except HTTP422UnprocessableEntityError:
            logger.debug(
                "422 attempting to update ref, ref: %s, sha %s in %s/%s.",
                ref,
                sha,
                self.kwargs["owner"],
                self.kwargs["repo"],
            )
            return None

    def getIssueCommentsForHeader(self, pr, comment_header):
        comments = self.getIssueComments(pr)
        if not comments:
            return []
        userComments = [c for c in comments]
        logger.debug("Found %d comments on PR #%s", len(userComments), pr)
        logger.debug("Looking for comment that starts with '%s'", comment_header)
        return [c for c in userComments if c.body.startswith(comment_header)]

    def PushChangeLog(self, path: str, content: str, branch: str) -> None:
        blob = self.createGitBlob(content)
        logger.debug(blob)
        branchRef = self.getHead(f"heads/{branch}")
        head_sha = branchRef.object.sha
        logger.debug(head_sha)
        base_tree = self.getGitTree(tree_sha=head_sha)
        tree = self.createGitTree(
            tree_sha=base_tree.sha,
            tree=[dict(path=path, sha=blob.sha, mode="100644", type="blob")],
        )
        commit = self.createCommit(
            message="adding changelog",
            tree_sha=tree.sha,
            parents=[head_sha],
            author=dict(name=self.pr_author_name, email=self.pr_author_email),
        )
        update = self.updateRef(ref=f"heads/{branch}", sha=commit.sha)
        logger.debug(update)

    def getReleaseByTag(self, tag: str):
        try:
            return self.api.repos.get_release_by_tag(**self.kwargs, tag=tag)
        except (HTTP404NotFoundError, HTTP422UnprocessableEntityError):
            logger.debug("404 attempting to get a release, tag: %s.", tag)
            return None

    def createRelease(self, tag: str, name: str, body: str):
        try:
            return self.api.repos.create_release(
                **self.kwargs,
                tag_name=tag,
                name=name,
                body=body,
                draft=False,
                prerelease=False,
            )
        except HTTP422UnprocessableEntityError:
            logger.debug("422 attempting to create a release, tag: %s.", tag)
            return None

    def getAllTags(self):
        return self.getMatchingRefs("tags/")

    def getMatchingRefs(self, ref):
        return self.api.git.list_matching_refs(**self.kwargs, ref=ref)

    def createTag(self, tag, sha):
        return self.createRef("refs/tags/" + tag, sha)

    def createRef(self, ref, sha):
        try:
            return self.api.git.create_ref(**self.kwargs, ref=ref, sha=sha)
        except HTTP422UnprocessableEntityError:
            logger.debug("422 attempting to create a release branch, sha: %s.", sha)
            return None

    def addLabels(self, pr, labels):
        return self.api.issues.add_labels(**self.kwargs, issue_number=pr, labels=labels)

    def listLabels(self, pr):
        return self.api.issues.list_labels_on_issue(
            **self.kwargs, issue_number=pr, per_page=100
        )

    def removeLabel(self, pr, label):
        try:
            return self.api.issues.remove_label(
                **self.kwargs, issue_number=pr, name=label
            )
        except HTTP404NotFoundError:
            return None

    # https://stackoverflow.com/questions/53859199/how-to-cherry-pick-through-githubs-api
    def createCherryPick(self, base_branch_name: str, commit_sha: str) -> str | None:
        commit = self.getCommit(sha=commit_sha, branch=self.getDefaultBranch())
        if not commit:
            logger.warn("commit to cherry pick not found")
            return None
        base_branch = self.getBranch(base_branch_name)
        base_sha = base_branch.commit.sha
        base_tree = base_branch.commit.commit.tree.sha
        author = {"name": self.pr_author_name, "email": self.pr_author_email}
        parent_sha = commit.parents[0].sha
        temp_commit = self.createCommit(
            message="temp commit",
            tree_sha=base_tree,
            parents=[parent_sha],
            author=author,
        )
        if not temp_commit or not temp_commit.sha:
            logger.debug("temp commit or its SHA in cherry pick is None")
            return None
        commit_prefix = commit_sha[0:6]
        cherry_pick_branch_name = f"cherry-pick-{base_branch_name}-{commit_prefix}"
        cherry_pick_branch_ref = "heads/" + cherry_pick_branch_name
        self.createBranch(cherry_pick_branch_name, base_sha)
        try:
            self.updateRef(cherry_pick_branch_ref, temp_commit.sha, True)
            merge = self.api.repos.merge(
                **self.kwargs, base=cherry_pick_branch_name, head=commit.sha
            )
            merge_tree = merge.commit.tree.sha
            cherry_pick_commit = self.createCommit(
                commit.commit.message, merge_tree, [base_sha], author
            )
            self.updateRef(cherry_pick_branch_ref, cherry_pick_commit.sha, True)
        except Exception as e:
            logger.debug(f"error thrown when creating cherry pick: {str(e)}")
            self.deleteBranch(cherry_pick_branch_name)
            raise e
        return cherry_pick_branch_name

    def createPr(self, head, base, pull_number: int | None):
        repo_name = f"{self.kwargs['owner']}/{self.kwargs['repo']}"
        repo = self.pygithub.get_repo(repo_name)
        message = f"cherry pick from master to {base}"
        if pull_number is not None:
            message = f"cherry pick from #{pull_number} to {base}"
        pr = repo.create_pull(message, body="", head=head, base=base)
        return pr

class WitnessTestifyConfig:
    def __init__(self, testify_config={}):
        self.excludes = testify_config.get("excludes", {})
        self.read_pr_title = testify_config.get("read_pr_title", True)
        self.always_release_minor = testify_config.get("always_release_minor", False)

class WitnessInvestigateConfig:
    REPO_TYPES = ["highlights", "excludes"]

    def __init__(self, investigate_config={}):
        self.excludes = {}
        self.release_branch = investigate_config.get("release_branch", False)
        self.valid_branches_only = investigate_config.get("valid_branches_only", True)
        self.required_status_checks = investigate_config.get(
            "required_status_checks", False
        )
        self.deployment = investigate_config.get("deployment", False)
        self.accept_minor = investigate_config.get("accept_minor", False)
        for exclude in investigate_config.get("excludes", []):
            self.excludes[exclude] = True
        self.repos = {}
        repos_config = investigate_config.get("repos", {})
        for REPO_TYPE in self.REPO_TYPES:
            self.repos[REPO_TYPE] = {}
            for repo in repos_config.get(REPO_TYPE, []):
                self.repos[REPO_TYPE][repo] = True
        self.repos["blacklisted_branches"] = {}
        for repo, branches in repos_config.get("blacklisted_branches", {}).items():
            branches_dict = {}
            for branch in branches:
                branches_dict[branch] = True
            self.repos["blacklisted_branches"][repo] = branches_dict


class WitnessConfig:
    def __init__(self):
        self.testify = WitnessTestifyConfig()
        self.investigate = WitnessInvestigateConfig()
        self.software_modules = {}

    @staticmethod
    def create(repo: Repo, branch: str = "master"):
        witness_config = WitnessConfig()
        config = {}
        if os.path.exists(".witness/config.yml"):
            textIOWrapper = open(".witness/config.yml")
            config = yaml.safe_load(textIOWrapper)
        else:
            text = repo.getFileContent(".witness/config.yml", branch)
            if text is not None:
                config = yaml.safe_load(text)

        witness_config.testify = WitnessTestifyConfig(config.get("testify", {}))
        witness_config.investigate = WitnessInvestigateConfig(
            config.get("investigate", {})
        )
        for module in config.get("software_modules", []):
            witness_config.software_modules[module] = True
        return witness_config

class Change:
    @staticmethod
    def getChangeTypeFromString(change_type):
        ct = ("".join([c for c in change_type if c.isalpha()])).casefold()
        ct = CHANGE_TYPES.get(ct)
        if ct:
            return ct
        else:
            raise Exception(f"Change type {change_type} unknown.")

    @staticmethod
    def getStringFromChangeType(change_type):
        ct = _CHANGE_TYPES_STR.get(change_type)
        if ct:
            return ct
        else:
            return "invalid type"

    def __init__(
        self,
        name: str,
        change_type: str,
        title: str,
        description: str,
        breaking: str,
        links: List[str],
        software_modules: List[str] = [],
    ):
        self.name = name
        self.type = change_type
        self.title = title
        self.software_modules = software_modules
        self.description = description
        self.breaking = breaking
        self.links = links

    def getType(self):
        if isinstance(self.type, ChangeType):
            return self.type
        else:
            return ChangeType._invalid

    @staticmethod
    def create(name, file_content):
        y = yaml.safe_load(file_content)
        change_type = y.get("type")
        try:
            change_type = Change.getChangeTypeFromString(change_type)
        except Exception:
            pass
        title = y.get("title")
        title = title and title.strip()
        description = y.get("description")
        description = description and description.strip()
        breaking = y.get("breaking")
        breaking = breaking and breaking.strip()
        software_modules = y.get("software_modules", [])
        links = y.get("links")
        return Change(
            name, change_type, title, description, breaking, links, software_modules
        )

    def getChangeFileContent(self):
        output = []
        output.append(f'type: "{self.getStringFromChangeType(self.type)}"')
        if self.breaking != "":
            output.append(f'breaking: "{self.breaking}"')
        output.append(f'description: "{self.description}"')
        if len(self.software_modules) > 0:
            output.append("software_modules:")
            for module in self.software_modules:
                output.append(f"  - {module}")
        output.append("links:")
        for link in self.links or []:
            output.append(f"  {link}")
        output.append("")
        return "\n".join(output)

    def is_valid(self):
        try:
            return bool(
                isinstance(self.type, ChangeType) and (self.title or self.description)
            )
        except Exception:
            return False

    def get_markdown(self):
        # Build the first line incrementally.
        typeStr = self.getStringFromChangeType(self.type)
        output = f"|{typeStr}|"
        if self.description:
            d = self.description
            newLines = d.replace("\n", "<br />")
            if self.breaking:
                newLines += (
                    "<br />\U0001F4A5Breaking Change: "
                    + self.breaking.replace("\n", "<br />")
                    + "\U0001F4A5"
                )
            output += newLines + "|"
        elif self.title:
            output += f"{self.title}|"
        else:
            output += "no description|"
        for link in self.links or []:
            if isinstance(link, dict):
                for text, url in link.items():
                    output += f"[{text}]({url}) <br />"
            else:
                output += f"{link} <br />"
        output2 = [output]
        return "\n".join(output2)

logger = logging.getLogger(__name__)

def checkIfClicked(string: str) -> bool:
    if string.__contains__("[x]"):
        return True
    elif string.__contains__("[X]"):
        return True
    else:
        return False


class ChangeComment:
    repo: Repo
    CHANGELOG_DESCRIPTION = "Check the box to generate changelog"
    CREATE_TAG_DESCRIPTION = "Check the box to tag this commit when it gets pushed"
    CREATE_MULTIPLE_CHERRY_PICK_PR_DESCRIPTION = "Enter below the release branch names to create cherry pick PRs to, separated by commas:"
    LINKS_DESCRIPTION = "**Links** (just '- link' or '- <text: link>' on new lines)"
    BREAKING_DESCRIPTION = "**Breaking Change** (optional, if your change breaks functionality, explain how to mitigate the break)"
    LINK_TO_DOCS = "[Docs on witness change classification](https://dev/engineering-processes/release-management/software-change-process/software-change-classification.html)"
    TAG_LABEL = "create-tag"
    REPLACE_ME = "REPLACE ME"
    REPLACE_ME_BREAKING = "REPLACE ME IF BREAKING"

    def __init__(
        self,
        repo: Repo,
        pr: Num,
        branch: str,
        changelog_present: bool = False,
        witness_config: WitnessConfig = WitnessConfig(),
    ):
        self.pr = pr
        self.repo = repo
        self.branch = branch
        self.changelog_present = changelog_present
        self.output = self._output(witness_config)

    def _output(self, witness_config: WitnessConfig):
        output = []
        output.append("### Testify")

        if not self.changelog_present:
            title = self.repo.getPr(self.pr).title
            match = self.getConventionalCommitMatch(title)
            changeType = ""
            scopes = []
            description = ""
            read_pr_title = witness_config and witness_config.testify.read_pr_title
            if read_pr_title and match is not None:
                try:
                    changeType = Change.getStringFromChangeType(
                        Change.getChangeTypeFromString(match.group(1))
                    )
                except Exception:
                    pass
                if changeType != "":
                    logger.debug(bool(match.group(2)))
                    scopes = match.group(2).split(",") if bool(match.group(2)) else []
                    scopes = [scope.strip() for scope in scopes]
                    description = match.group(3) if bool(match.group(3)) else ""
            output.append("## Generate a Witness changelog")
            if not read_pr_title:
                output.append(
                    "**(Edit this comment to add your description instead of REPLACE ME)**"
                )
            output.append(ChangeComment.LINK_TO_DOCS)
            software_modules = witness_config.software_modules
            if len(software_modules) > 0:
                self._addCheckBoxes(
                    output, "Impacted Software Modules", software_modules, scopes
                )
            if isValidReleaseBranch(self.branch):
                if witness_config.investigate.accept_minor:
                    self._addCheckBoxes(
                        output,
                        "Type",
                        [
                            _CHANGE_TYPES_STR[ChangeType.CHORE],
                            _CHANGE_TYPES_STR[ChangeType.BUGFIX],
                            _CHANGE_TYPES_STR[ChangeType.MINOR],
                        ],
                        changeType,
                    )
                else:
                    self._addCheckBoxes(
                        output,
                        "Type",
                        [
                            _CHANGE_TYPES_STR[ChangeType.CHORE],
                            _CHANGE_TYPES_STR[ChangeType.BUGFIX],
                        ],
                        changeType,
                    )
            else:
                self._addCheckBoxes(output, "Type", CHANGE_TYPES, changeType)
            output.append("")
            output.append("**Description**")
            if read_pr_title:
                if changeType != "":
                    output.append(description.strip())
                else:
                    output.append(title)
            else:
                output.append(ChangeComment.REPLACE_ME)
            output.append("")
            output.append(ChangeComment.BREAKING_DESCRIPTION)
            output.append(ChangeComment.REPLACE_ME_BREAKING)
            output.append("")
            output.append(self.LINKS_DESCRIPTION)
            url = f"{self.repo.url}/pull/{self.pr}"
            output.append(f"- pr-{self.pr}: {url}")
            self._addCheckBoxes(
                output, self.CHANGELOG_DESCRIPTION, ["Generate changelog entry"], []
            )
        return output

    @staticmethod
    def _addCheckBoxes(
        output: List, description: str, buttons: dict | List, buttonsToCheck: str | List
    ):
        output.append("")
        output.append(f"**{description}**")
        for button in buttons:
            if button in buttonsToCheck:
                output.append(f"* [x]  {button}")
            else:
                output.append(f"* [ ]  {button}")

    @staticmethod
    def getConventionalCommitMatch(message: str) -> re.Match | None:
        return re.search(r"(^[^\[(]*)(?:[\[(](.*)[\])])?\s*:(.*)", message)

    @staticmethod
    def createChange(comment) -> Change:
        # take the last comment if there are multiple
        # github comments use \r and \n after edit
        body_arr = comment.split("\r\n")
        logger.debug(body_arr)
        # changelog_file = []
        try:
            modules_line = body_arr.index("**Impacted Software Modules**")
        except ValueError:
            modules_line = -1
        type_line = body_arr.index("**Type**")
        breaking_line = body_arr.index(ChangeComment.BREAKING_DESCRIPTION)
        desc_line = body_arr.index("**Description**")
        links_line = body_arr.index(ChangeComment.LINKS_DESCRIPTION)
        gen_line = body_arr.index(f"**{ChangeComment.CHANGELOG_DESCRIPTION}**")
        software_modules: List[str] = []
        if not checkIfClicked(body_arr[gen_line + 1]):
            raise Exception("changelog not ready for generation")
        software_modules = []
        if modules_line != -1:
            modules_arr = body_arr[modules_line:type_line]
            for line in modules_arr:
                if checkIfClicked(line):
                    module = line.replace("* [x] ", "")
                    module = module.replace("* [X] ", "")
                    module = module.strip()
                    software_modules.append(module)
        change_type = ""
        type_arr = body_arr[type_line:desc_line]
        for line in type_arr:
            if checkIfClicked(line):
                change_type = line.replace("* [x] ", "")
                change_type = change_type.replace("* [X] ", "")
                change_type = change_type.strip()
                break
        if change_type == "":
            raise Exception("type must be filled in")
        desc_lines = body_arr[desc_line + 1 : breaking_line]
        description = "\n".join(desc_lines).strip()
        # quotes break investigate
        description = description.replace('"', "")
        if description == "":
            raise Exception("description cannot be blank")
        elif len(description) < 5:
            raise Exception("description must be longer")
        elif ChangeComment.REPLACE_ME in description:
            raise Exception("description cannot be blank")
        logger.debug(description)
        breaking_ignore = ["no", "none", "nothing", "na", "no changes"]
        breaking_lines = body_arr[breaking_line + 1 : links_line]
        breaking = "\n".join(breaking_lines).strip()
        breaking_temp = breaking.lower().translate(
            str.maketrans("", "", string.punctuation)
        )
        if ChangeComment.REPLACE_ME in breaking or breaking_temp in breaking_ignore:
            breaking = ""
        links_arr = body_arr[links_line + 1 : gen_line]
        links_arr = [i for i in links_arr if i]
        return Change(
            "",
            Change.getChangeTypeFromString(change_type),
            "",
            description,
            breaking,
            links_arr,
            software_modules,
        )

    @staticmethod
    def updateLabels(repo: Repo, pr: Num, key_text="### Testify"):
        comments = repo.getIssueCommentsForHeader(pr, key_text)
        if not comments:
            return "no testify comment found, try closing/re-opening the PR or manually add the create-tag label to bypass"

        comment = comments[-1].body
        body_arr = comment.split("\r\n")
        tag_line = 0
        try:
            tag_line = body_arr.index(f"**{ChangeComment.CREATE_TAG_DESCRIPTION}**")
        except ValueError:
            return
        # leaving like this for now to make it easy to add more labels in as we need them
        labels = []
        if checkIfClicked(body_arr[tag_line + 1]):
            labels.append(ChangeComment.TAG_LABEL)
        else:
            repo.removeLabel(pr, ChangeComment.TAG_LABEL)

        if len(labels) > 0:
            repo.addLabels(pr, labels)

    @staticmethod
    def createChangeLog(
        repo: Repo, branch_name: str, pr: Num, key_text="### Testify"
    ) -> str | None:
        comments = repo.getIssueCommentsForHeader(pr, key_text)
        if comments:
            c = comments[-1]
            try:
                change = ChangeComment.createChange(c.body)
            except Exception as err:
                return str(err)
            content = change.getChangeFileContent()
            logger.debug(content)
            filename = f"changes/pr-{pr}.yml"
            logger.debug(filename)
            repo.PushChangeLog(filename, content, branch_name)
            return None

        else:
            return "no testify comment found, manually add a changelog to bypass err"

@click.option(
    "--headless-logdir",
    "headless_logdir",
    type=click.Path(),
    default=os.path.expanduser("~/goromail"),
    show_default=True,
    help="Directory in which to store log files for headless mode.",
)
def cli(
    ctx: click.Context,
    repo,
    pr,
    read_comment,
):
    branch_name = ""
    if pr and rev_b:
        ctx.fail("Can only specify --pr with a single PR# and no additional revisions.")
    repo_name, repo = repo, Repo(repo)
    if not rev_b:
        rev_b = rev_a
        rev_a = repo.getDefaultBranch()
    if pr:
        pr = rev_b
        pr_info = repo.getPr(rev_b)
        if pr_info:
            rev_a = pr_info.base.ref
            rev_b = pr_info.merge_commit_sha
            logger.info(pr_info.head.ref)
            branch_name = pr_info.head.ref
        else:
            ctx.fail(f"PR #{rev_b} not found in {repo_name}.")

    pr_change_filename = f"changes/pr-{pr}.yml"
    pr_change = repo.getFileContent(pr_change_filename, branch_name)
    changelogs = []
    if pr_change:
        changelogs.append(Change.create(pr_change_filename, pr_change))

    output = ["# Witness Corroborate"]

    if pr:
        labels_err = ChangeComment.updateLabels(repo, pr)

        if pr_info.state != "closed" and not changelogs:
            # check if comment is completed
            if read_comment:
                logger.debug("checking for change comment")
                err = ChangeComment.createChangeLog(
                    repo=repo, branch_name=branch_name, pr=pr
                )
                if err:
                    if labels_err:
                        err = labels_err + "\n" + err
                    ctx.fail(err)
                ctx.exit(0)
            else:
                output.append("\n* At least one change file must be added in this PR.")
                result = "\n".join(output)
                click.echo(result)
                ctx.exit(1)

    filename_regex = os.environ.get("WITNESS_FILENAME_FORMAT") or ".*"
    logger.info("Matching filename with regex: '%s'", filename_regex)
    filename_regex = re.compile(filename_regex)
    invalid_filenames = []
    successes = []
    errors = []
    for cl in changelogs:
        cl_path = cl.name.split("/")
        name = cl_path[1]
        if not filename_regex.match(name):
            invalid_filenames.append(name)
        if cl.is_valid():
            successes.append(name)
        else:
            errors.append(name)

    output.append("\n## Valid file contents\n")
    successes.sort()
    for fn in successes:
        output.append(f"- {fn}")

    if errors:
        output.append("\n## Invalid file contents\n")
        errors.sort()
        for fn in errors:
            output.append(f"- {fn}")

    if invalid_filenames:
        output.append("\n## Invalid filenames\n")
        invalid_filenames.sort()
        for fn in invalid_filenames:
            output.append(f"- {fn}")

    result = "\n".join(output)
    click.echo(result)

    ctx.exit(len(errors) + len(invalid_filenames))


def main():
    cli()


if __name__ == "__main__":
    main()
