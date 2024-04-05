# setupws

Create standalone development workspaces.

Unlike with [devshell](./devshell.md)'s `setupcurrentws` command, this tool takes all of its setup info from the CLI:

```
usage: setupws [OPTIONS] workspace_name srcname:git_url [srcname:git_url ...]

Create a development workspace with specified git sources.

Options:
    --dev_dir [DIRNAME]        Specify the root directory where the [workspace_name] source
                               directory will be created (default: ~/dev)

    --data_dir [DIRNAME]       Specify the root directory where the [workspace_name] mutable 
                               data will be stored (default: ~/data)

```

