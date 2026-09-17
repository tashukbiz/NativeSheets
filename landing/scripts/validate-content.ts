/**
 * Validates the content registry on its own, outside a build. The same
 * validation runs when the registry is imported, so a failing build fails here
 * too; this script exists to get a readable report without a full build.
 */
import { allContent, routeOf, validateContent } from "../src/site/content/index";

const issues = validateContent();
if (issues.length > 0) {
  console.error(`${issues.length} content problem(s):`);
  for (const issue of issues) console.error(`  ${issue.recordId}: ${issue.problem}`);
  process.exit(1);
}

console.log(`${allContent.length} records validated:`);
for (const record of allContent) {
  console.log(`  ${record.status.padEnd(9)} ${record.type.padEnd(8)} ${routeOf(record)}`);
}
