"use client";

import * as React from "react";
import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
  type ColumnDef,
  type SortingState,
} from "@tanstack/react-table";
import { ArrowDown, ArrowUp, ChevronsUpDown, Download } from "lucide-react";
import { cn } from "@/lib/utils";
import { toBn } from "@/lib/bn";
import { downloadCsvSafe } from "@/lib/csv";
import { EmptyState } from "./states";
import { TableSkeleton } from "./skeleton";
import { ErrorState } from "./states";
import { Button } from "./button";

interface DataTableProps<T> {
  columns: ColumnDef<T, unknown>[];
  data: T[] | undefined;
  loading?: boolean;
  error?: unknown;
  onRetry?: () => void;
  onRowClick?: (row: T) => void;
  rowAriaLabel?: (row: T) => string;
  emptyTitle?: string;
  emptyHint?: string;
  emptyAction?: React.ReactNode;
  csvFilename?: string;
  csvHeaders?: string[];
  csvRow?: (row: T) => (string | number | null | undefined)[];
  maxHeight?: string;
  className?: string;
}

/** Dense data table — sticky header, sortable columns, keyboard navigation,
 *  CSV export, designed empty/error states. */
export function DataTable<T>({
  columns,
  data,
  loading,
  error,
  onRetry,
  onRowClick,
  rowAriaLabel,
  emptyTitle = "কোনো তথ্য নেই",
  emptyHint,
  emptyAction,
  csvFilename,
  csvHeaders,
  csvRow,
  maxHeight = "max-h-[65vh]",
  className,
}: DataTableProps<T>) {
  const [sorting, setSorting] = React.useState<SortingState>([]);

  // TanStack Table v8 is not React-Compiler-compatible — compilation is
  // skipped for this hook call (informational, not a defect).
  // eslint-disable-next-line react-hooks/incompatible-library
  const table = useReactTable({
    data: data ?? [],
    columns,
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  });

  if (loading) return <TableSkeleton cols={Math.max(columns.length, 3)} />;
  if (error) return <ErrorState error={error} onRetry={onRetry} className="border-0" />;

  const rows = table.getRowModel().rows;

  const exportCsv = () => {
    if (!csvFilename || !csvHeaders || !csvRow || !data) return;
    downloadCsvSafe(csvFilename, csvHeaders, data.map(csvRow));
  };

  return (
    <div className={cn("flex flex-col gap-2", className)}>
      {csvFilename && csvHeaders && csvRow && data && data.length > 0 ? (
        <div className="no-print flex justify-end">
          <Button variant="outline" size="sm" onClick={exportCsv}>
            <Download className="h-4 w-4" aria-hidden />
            CSV ডাউনলোড
          </Button>
        </div>
      ) : null}
      <div className={cn("scroll-thin overflow-auto rounded-lg border border-border bg-card shadow-card", maxHeight)}>
        <table className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10">
            {table.getHeaderGroups().map((hg) => (
              <tr key={hg.id} className="bg-muted/95 backdrop-blur">
                {hg.headers.map((header) => {
                  const canSort = header.column.getCanSort();
                  const sorted = header.column.getIsSorted();
                  return (
                    <th
                      key={header.id}
                      scope="col"
                      aria-sort={sorted === "asc" ? "ascending" : sorted === "desc" ? "descending" : undefined}
                      className={cn(
                        "whitespace-nowrap border-b border-border px-3.5 py-2.5 text-left text-xs font-bold text-muted-foreground",
                        canSort && "cursor-pointer select-none hover:text-foreground"
                      )}
                      onClick={canSort ? header.column.getToggleSortingHandler() : undefined}
                    >
                      <span className="inline-flex items-center gap-1">
                        {flexRender(header.column.columnDef.header, header.getContext())}
                        {canSort ? (
                          sorted === "asc" ? (
                            <ArrowUp className="h-3 w-3 text-primary" aria-hidden />
                          ) : sorted === "desc" ? (
                            <ArrowDown className="h-3 w-3 text-primary" aria-hidden />
                          ) : (
                            <ChevronsUpDown className="h-3 w-3 opacity-40" aria-hidden />
                          )
                        ) : null}
                      </span>
                    </th>
                  );
                })}
              </tr>
            ))}
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="p-0">
                  <EmptyState title={emptyTitle} hint={emptyHint} action={emptyAction} className="border-0 bg-transparent" />
                </td>
              </tr>
            ) : (
              rows.map((row) => (
                <tr
                  key={row.id}
                  tabIndex={onRowClick ? 0 : undefined}
                  aria-label={rowAriaLabel ? rowAriaLabel(row.original) : undefined}
                  onClick={onRowClick ? () => onRowClick(row.original) : undefined}
                  onKeyDown={
                    onRowClick
                      ? (e) => {
                          if (e.key === "Enter" || e.key === " ") {
                            e.preventDefault();
                            onRowClick(row.original);
                          }
                        }
                      : undefined
                  }
                  className={cn(
                    "border-b border-border/60 last:border-b-0",
                    onRowClick &&
                      "cursor-pointer transition-colors duration-150 hover:bg-primary-soft/60 focus:bg-primary-soft/60 focus:outline-none"
                  )}
                >
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className="px-3.5 py-2.5 align-middle">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      {data ? (
        <p className="text-xs text-muted-foreground" aria-live="polite">
          সর্বমোট {toBn(data.length)} টি সারি
        </p>
      ) : null}
    </div>
  );
}
