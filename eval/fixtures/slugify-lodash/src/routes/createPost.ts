import { slugify } from "../lib/slugify";

export function createPost(title: string, body: string) {
  const slug = slugify(title);
  return { slug, title, body };
}
