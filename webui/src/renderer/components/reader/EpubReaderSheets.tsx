import type { EpubPrefs } from '@/store/readerStore';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import { FONT_FAMILIES, FONT_SIZES } from '../../../shared/epubTheme';

interface EpubChapter {
  href: string;
  label?: string;
}

interface EpubChaptersSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  chapters: EpubChapter[];
  onChapterClick: (href: string) => void;
}

export function EpubChaptersSheet({
  open,
  onOpenChange,
  chapters,
  onChapterClick,
}: EpubChaptersSheetProps) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="left" className="bg-zinc-950 border-zinc-800 text-zinc-100 max-w-sm flex flex-col">
        <SheetHeader className="pb-4 border-b border-zinc-800 shrink-0">
          <SheetTitle className="text-zinc-100 text-left font-bold uppercase tracking-wider text-sm">
            Table of Contents
          </SheetTitle>
        </SheetHeader>
        <div
          className="flex-1 min-h-0 overflow-y-auto mt-4 space-y-1 pr-2 no-scrollbar"
          style={{ touchAction: 'pan-y' }}
        >
          {chapters.length === 0 ? (
            <p className="text-xs text-zinc-500 italic p-4 text-center">No chapters found.</p>
          ) : (
            chapters.map((chapter, index) => (
              <button
                key={index}
                onClick={() => onChapterClick(chapter.href)}
                className="w-full text-left px-3 py-2.5 rounded text-xs font-medium text-zinc-300 hover:text-zinc-100 hover:bg-zinc-800/40 transition-colors truncate cursor-pointer"
              >
                {chapter.label?.trim() || `Chapter ${index + 1}`}
              </button>
            ))
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}

interface EpubSettingsSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  prefs: EpubPrefs;
  localGoogleFont: string;
  onLocalGoogleFontChange: (value: string) => void;
  onPrefsChange: (prefs: Partial<EpubPrefs>) => void;
  onApplyGoogleFont: () => void;
  onSpreadChange: (checked: boolean) => void;
}

export function EpubSettingsSheet({
  open,
  onOpenChange,
  prefs,
  localGoogleFont,
  onLocalGoogleFontChange,
  onPrefsChange,
  onApplyGoogleFont,
  onSpreadChange,
}: EpubSettingsSheetProps) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="bg-zinc-950 border-zinc-800 text-zinc-100 max-w-sm">
        <SheetHeader className="pb-4 border-b border-zinc-800">
          <SheetTitle className="text-zinc-100 text-left font-bold uppercase tracking-wider text-sm">
            Display Preferences
          </SheetTitle>
        </SheetHeader>
        <div className="flex-1 space-y-6 mt-6">
          <div className="space-y-2">
            <Label className="text-xs font-bold uppercase tracking-wider text-zinc-400">
              Reading Theme
            </Label>
            <div className="flex items-center gap-2">
              <Button
                variant={prefs.themeMode === 'white' ? 'default' : 'outline'}
                size="sm"
                onClick={() => onPrefsChange({ themeMode: 'white' })}
                className="flex-1 font-semibold"
              >
                Light
              </Button>
              <Button
                variant={prefs.themeMode === 'black' ? 'default' : 'outline'}
                size="sm"
                onClick={() => onPrefsChange({ themeMode: 'black' })}
                className="flex-1 font-semibold"
              >
                Dark
              </Button>
            </div>
          </div>

          <div className="space-y-2">
            <Label className="text-xs font-bold uppercase tracking-wider text-zinc-400">
              Font Style
            </Label>
            <Select value={prefs.fontFamily} onValueChange={(val) => onPrefsChange({ fontFamily: val })}>
              <SelectTrigger className="bg-zinc-900 border-zinc-800 h-9">
                <SelectValue placeholder="Choose Font" />
              </SelectTrigger>
              <SelectContent className="bg-zinc-900 border-zinc-800 text-zinc-100">
                {FONT_FAMILIES.map((font) => (
                  <SelectItem key={font.value} value={font.value}>
                    {font.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label className="text-xs font-bold uppercase tracking-wider text-zinc-400">
              Font Size
            </Label>
            <Select value={String(prefs.fontSize)} onValueChange={(val) => onPrefsChange({ fontSize: Number(val) })}>
              <SelectTrigger className="bg-zinc-900 border-zinc-800 h-9">
                <SelectValue placeholder="Choose Size" />
              </SelectTrigger>
              <SelectContent className="bg-zinc-900 border-zinc-800 text-zinc-100">
                {FONT_SIZES.map((size) => (
                  <SelectItem key={size} value={String(size)}>
                    {size}%
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label className="text-xs font-bold uppercase tracking-wider text-zinc-400">
              Google Web Font
            </Label>
            <div className="flex gap-2">
              <Input
                type="text"
                placeholder="e.g. EB Garamond"
                value={localGoogleFont}
                onChange={(event) => onLocalGoogleFontChange(event.target.value)}
                className="bg-zinc-900 border-zinc-800 h-9 text-xs"
              />
              <Button
                variant="secondary"
                size="sm"
                onClick={onApplyGoogleFont}
                className="h-9 font-semibold text-xs"
              >
                Apply
              </Button>
            </div>
          </div>

          <div className="flex items-center justify-between pt-2 border-t border-zinc-900">
            <div className="flex flex-col gap-0.5">
              <Label className="text-xs font-bold uppercase tracking-wider text-zinc-400">
                Double Page Mode
              </Label>
              <span className="text-[10px] text-zinc-500">Enable 2-page columns in landscape</span>
            </div>
            <Switch checked={prefs.spread} onCheckedChange={onSpreadChange} />
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
