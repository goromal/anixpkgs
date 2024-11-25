{ }:
# https://www.gnu.org/software/bash/manual/html_node/Redirections.html
rec {
  null_dest = "/dev/null";
  redirect_stdout = dest: "1> ${dest}";
  redirect_stderr = dest: "2> ${dest}";
  redirect_all = dest: "> ${dest} 2>&1";
  stderr_to_stdout = "2>&1";
  suppress_stdout = redirect_stdout null_dest;
  suppress_stderr = redirect_stderr null_dest;
  suppress_all = redirect_all null_dest;
}
