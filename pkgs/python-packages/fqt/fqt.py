import click, os, random, datetime

def getClasses(cfgfile):
    class_names = []
    class_weights = []
    total_weight = 0.0
    with open(os.path.expanduser(cfgfile), "r") as cfg:
        for line in cfg:
            class_name = line.split(":")[0]
            class_names.append(class_name)
            class_weight = float(line.split(":")[1])
            class_weights.append(class_weight)
            total_weight += class_weight
    cum_weight = 0.0
    classes = []
    for cname, cweight in zip(class_names, class_weights):
        cum_weight2 = cum_weight + cweight / total_weight
        classes.append((cname, (cum_weight, cum_weight2)))
        cum_weight = cum_weight2
    return classes

@click.group()
@click.pass_context
@click.option(
    "--config-file",
    "config_file",
    type=click.Path(),
    default="~/fqt/config",
    show_default=True,
    help="Path to the config file.",
)
@click.option(
    "--log-file",
    "log_file",
    type=click.Path(),
    default="~/fqt/log",
    show_default=True,
    help="Path to the log file.",
)
def cli(ctx: click.Context, config_file, log_file):
    """Four-quadrants tasking tools."""
    ctx.obj = {"cfg": config_file, "log": log_file}

@cli.command()
@click.pass_context
def task(ctx: click.Context):
    """Propose a task for the day."""
    try:
        classes = getClasses(ctx.obj["cfg"])
    except:
        print("ERROR: mal-formed config file.")
        exit(1)
    key = random.uniform(0., 1.)
    chosen_class = None
    for class_name, class_range in classes:
        if class_range[0] <= key <= class_range[1]:
            chosen_class = class_name
    if chosen_class is None:
        print("ERROR: random choice calculation error.")
        exit(1)
    print(f"Chosen task: {chosen_class}")
    response = None
    while response is None:
        response = input("Proceed? [Y/N] ").lower()
        if response == "y":
            print("Great!")
        elif response == "n":
            while response == "n":
                response = input("Why not? Urgency [U] or Energy [E]? ").lower()
                if response != "u" and response != "e":
                    print("Response not understood.")
                    response = "n"
                else:
                    print("Very well.")
        else:
            print("Response not understood.")
            response = None
    with open(os.path.expanduser(ctx.obj["log"]), "a") as log:
        log.write(f"{datetime.datetime.now()}|{chosen_class}|{response}\n")

@cli.command()
@click.pass_context
def analyze(ctx: click.Context):
    """Analyze past task performance."""
    print("TODO")

def main():
    cli()

if __name__ == '__main__':
    main()
