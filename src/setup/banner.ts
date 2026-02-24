import chalk from "chalk";

export function showBanner(): void {
  console.log("");
  
  // Money-themed gradient: gold -> green
  const gold = chalk.hex("#FFD700");
  const lime = chalk.hex("#32CD32");
  const green = chalk.hex("#00FF00");
  
  const banner = `
███╗   ███╗ ██████╗ ███╗   ██╗███████╗██╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗
████╗ ████║██╔═══██╗████╗  ██║██╔════╝╚██╗ ██╔╝██╔════╝██║     ██╔══██╗██║    ██║
██╔████╔██║██║   ██║██╔██╗ ██║█████╗   ╚████╔╝ ██║     ██║     ███████║██║ █╗ ██║
██║╚██╔╝██║██║   ██║██║╚██╗██║██╔══╝    ╚██╔╝  ██║     ██║     ██╔══██║██║███╗██║
██║ ╚═╝ ██║╚██████╔╝██║ ╚████║███████╗   ██║   ╚██████╗███████╗██║  ██║╚███╔███╔╝
╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ 
`;

  // Apply gradient effect line by line
  const lines = banner.split('\n');
  const colors = [gold, gold, lime, lime, green, green];
  
  lines.forEach((line, i) => {
    if (line.trim()) {
      const color = colors[Math.min(i, colors.length - 1)];
      console.log(color(line));
    }
  });

  console.log("");
  console.log(chalk.dim("  v0.1.0 — To exist, you must pay for your compute."));
  console.log(chalk.dim("  " + gold("$") + " Sovereign AI Runtime " + green("$")));
  console.log("");
}
