import type { MouseEvent, ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

interface SidebarSectionProps {
  title: string;
  addLabel?: string;
  onAdd?: () => void;
  children: ReactNode;
}

export function SidebarSection({
  title,
  addLabel,
  onAdd,
  children,
}: SidebarSectionProps) {
  return (
    <div className="space-y-1">
      <div className="flex items-center justify-between px-3 mb-2">
        <h3 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
          {title}
        </h3>
        {onAdd && (
          <Button
            variant="ghost"
            size="icon"
            onClick={onAdd}
            className="h-4 w-4 p-0 hover:bg-muted rounded text-muted-foreground hover:text-foreground"
            aria-label={addLabel}
          >
            <Plus className="h-3 w-3" />
          </Button>
        )}
      </div>
      {children}
    </div>
  );
}

interface SidebarNavLinkProps {
  to: string;
  active: boolean;
  icon: ReactNode;
  label: string;
  count?: number;
  onContextMenu?: (event: MouseEvent) => void;
}

export function SidebarNavLink({
  to,
  active,
  icon,
  label,
  count,
  onContextMenu,
}: SidebarNavLinkProps) {
  const link = (
    <Link
      to={to}
      className={cn(
        "w-full flex items-center gap-3 px-3 py-2 text-sm font-medium rounded-md transition-colors",
        active
          ? "bg-primary text-primary-foreground"
          : "text-muted-foreground hover:bg-muted hover:text-foreground",
      )}
    >
      {icon}
      <span className="truncate flex-1">{label}</span>
      {count !== undefined && (
        <span className="text-[10px] text-muted-foreground bg-secondary/80 px-1.5 py-0.5 rounded border border-border">
          {count}
        </span>
      )}
    </Link>
  );

  if (!onContextMenu) return link;

  return (
    <div onContextMenu={onContextMenu}>
      {link}
    </div>
  );
}

export function SidebarEmptyState({ children }: { children: ReactNode }) {
  return (
    <p className="px-3 text-xs text-muted-foreground/60 italic">
      {children}
    </p>
  );
}

export function SidebarLoadingState() {
  return <p className="px-3 text-xs text-muted-foreground/60">Loading...</p>;
}
