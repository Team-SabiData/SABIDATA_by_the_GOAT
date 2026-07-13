import { type ReactNode } from 'react';
import { EmptyState } from './EmptyState';

export type Column<T> = { key: string; label: string; width?: number | string; render?: (row: T) => ReactNode };

export function DataTable<T>({ columns, rows, rowKey, onRowClick, emptyTitle = 'Aucune donnée' }: {
  columns: Column<T>[]; rows: T[]; rowKey: (r: T) => string;
  onRowClick?: (r: T) => void; emptyTitle?: string;
}) {
  if (rows.length === 0) return <EmptyState title={emptyTitle} />;
  return (
    <table>
      <thead>
        <tr>{columns.map((c) => <th key={c.key} style={{ width: c.width }}>{c.label}</th>)}</tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <tr key={rowKey(r)} onClick={onRowClick ? () => onRowClick(r) : undefined}
            style={onRowClick ? { cursor: 'pointer' } : undefined}>
            {columns.map((c) => (
              <td key={c.key}>{c.render ? c.render(r) : String((r as Record<string, unknown>)[c.key] ?? '—')}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
