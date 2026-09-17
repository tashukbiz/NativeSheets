import type { Author } from "./types";

export const authors: Author[] = [
  {
    id: "tashuk",
    name: "tashuk",
    role: "Developer of Native Sheets",
    bio: "Writes and maintains Native Sheets, including the .xlsx reader and writer, the formula engine and the grid. Articles here describe behaviour that exists in that code and in its test suite.",
  },
];

export function authorById(id: string): Author {
  const found = authors.find((author) => author.id === id);
  if (!found) throw new Error(`Unknown author id: ${id}`);
  return found;
}
