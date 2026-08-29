// Off-by-one: the last item of each page is dropped.
export function paginate<T>(items: T[], page: number, pageSize: number): T[] {
  const start = page * pageSize;
  const end = start + pageSize - 1; // line 12, bug: should be `start + pageSize`
  return items.slice(start, end);
}
