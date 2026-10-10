import type * as React from 'react';
export interface ShellLane { title: string; count?: number | string; actions?: React.ReactNode; content?: React.ReactNode; dot?: boolean; width?: number }
export interface ShellProps { blob?: React.ReactNode; trailing?: React.ReactNode; lanes: [ShellLane, ShellLane, ShellLane]; className?: string; style?: React.CSSProperties }
export declare function Shell(props: ShellProps): React.ReactElement;
export interface LaneProps { title: string; count?: number | string; actions?: React.ReactNode; children?: React.ReactNode; folded?: boolean; onUnfold?: () => void; dot?: boolean }
export declare function Lane(props: LaneProps): React.ReactElement;
export interface LaneHandleProps { value?: number; label?: string; onStart?: () => void; onDrag?: (dx: number) => void; onEnd?: () => void; onStep?: (dx: number) => void; onReset?: () => void }
export declare function LaneHandle(props: LaneHandleProps): React.ReactElement;
export interface BlobProps { areas?: string[]; area?: string; onSelect?: (area: string) => void; onAssistant?: () => void; notice?: boolean; noticeArea?: string; side?: 'leading' | 'trailing'; onDock?: (side: 'leading' | 'trailing') => void }
export declare function Blob(props: BlobProps): React.ReactElement;
export interface TileItem { name: string; count?: number | string; links?: string[] }
export interface TileMenuProps { items: TileItem[]; onPick?: (name: string, link: string) => void; mass?: number; stiffness?: number; damping?: number }
export declare function TileMenu(props: TileMenuProps): React.ReactElement;
export interface MessageRowProps { from: string; date?: string; subject?: string; preview?: string; unread?: boolean; attachments?: boolean; selected?: boolean; onClick?: () => void }
export declare function MessageRow(props: MessageRowProps): React.ReactElement;
export interface SyncButtonProps { state?: 'fresh' | 'aged' | 'syncing' | 'error'; onClick?: () => void; label?: string }
export declare function SyncButton(props: SyncButtonProps): React.ReactElement;
export interface PersonMarkProps { initials: string; name?: string }
export declare function PersonMark(props: PersonMarkProps): React.ReactElement;
export interface TextButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> { variant?: 'well' | 'selected' | 'plain'; size?: 'small' | 'regular' | 'large' }
export declare function TextButton(props: TextButtonProps): React.ReactElement;
export interface SymbolButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> { symbol: string; label: string; variant?: 'plain' | 'well' | 'selected'; size?: 'small' | 'regular' | 'large' }
export declare function SymbolButton(props: SymbolButtonProps): React.ReactElement;
export interface ChipProps { selected?: boolean; onClick?: () => void; onRemove?: () => void; inRow?: boolean; children?: React.ReactNode }
export declare function Chip(props: ChipProps): React.ReactElement;
export interface SearchFieldProps { value?: string; defaultValue?: string; onChange?: (value: string) => void; placeholder?: string; compact?: boolean; id?: string; label?: string }
export declare function SearchField(props: SearchFieldProps): React.ReactElement;
export interface SymbolProps { name: 'search' | 'sync' | 'compose' | 'archive' | 'trash' | 'reply' | 'more' | 'close' | 'star' | 'inbox' | 'attach' | 'chevron' | 'check' | 'sidebar' | 'minus' | 'expand' | 'shrink' | 'link' | 'send' | 'eye' | 'plus'; size?: number }
export declare function Symbol(props: SymbolProps): React.ReactElement;
export type ExpressionColor = 'red-200' | 'red-400' | 'red-500' | 'red-700' | 'red-800' | 'orange-400' | 'cyan-900' | 'gray-950';
export interface ArcBarsProps { data: { label: string; value: number }[]; title?: string; caption?: string; className?: string }
export declare function ArcBars(props: ArcBarsProps): React.ReactElement;
export interface PillStackProps { items: { label: string; color?: ExpressionColor }[]; className?: string }
export declare function PillStack(props: PillStackProps): React.ReactElement;
export interface TooltipProps { title?: string; tone?: 'light' | 'dark'; tail?: boolean; children?: React.ReactNode; className?: string }
export declare function Tooltip(props: TooltipProps): React.ReactElement;
export interface DotSphereProps { size?: number; count?: number; label?: string; className?: string }
export declare function DotSphere(props: DotSphereProps): React.ReactElement;
export interface GlowButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {}
export declare function GlowButton(props: GlowButtonProps): React.ReactElement;
export interface AgentPillProps { label?: string; paused?: boolean; className?: string }
export declare function AgentPill(props: AgentPillProps): React.ReactElement;
export interface NumberRollProps { value: number; digits?: number; size?: number; className?: string }
export declare function NumberRoll(props: NumberRollProps): React.ReactElement;
export interface SpotlightGridProps { items?: React.ReactNode[]; count?: number; columns?: number; className?: string }
export declare function SpotlightGrid(props: SpotlightGridProps): React.ReactElement;
export interface StackedCardsProps { items: { title: string; note?: string; color?: ExpressionColor }[]; className?: string }
export declare function StackedCards(props: StackedCardsProps): React.ReactElement;
export interface KanbanColumn { id: string; title: string; cards: { id: string; text: string }[] }
export interface KanbanBoardProps { columns: KanbanColumn[]; onChange?: (columns: KanbanColumn[]) => void; className?: string }
export declare function KanbanBoard(props: KanbanBoardProps): React.ReactElement;
export interface ReadingPaneProps { subject: string; from: string; meta?: string; tag?: string; actions?: { label: string; onClick?: () => void }[]; children?: React.ReactNode; className?: string }
export declare function ReadingPane(props: ReadingPaneProps): React.ReactElement;
export interface HubTileProps { eyebrow: string; title: string; subtitle?: string; status?: 'ok' | 'error'; statusLabel?: string; onClick?: () => void; className?: string }
export declare function HubTile(props: HubTileProps): React.ReactElement;
export interface EditSheetLane { title: string; count?: number | string; actions?: React.ReactNode; content?: React.ReactNode; dot?: boolean; width?: number; min?: number; max?: number }
export interface EditSheetProps { lanes: [EditSheetLane, EditSheetLane, EditSheetLane]; blob?: React.ReactNode; className?: string; style?: React.CSSProperties }
export declare function EditSheet(props: EditSheetProps): React.ReactElement;
export interface BlobMenuItem { name: string; count?: number | string; links?: string[] }
export interface BlobDock { edge: 'left' | 'right' | 'top' | 'bottom'; at: number }
export interface BlobMenuProps { items: BlobMenuItem[]; current?: string; onSelect?: (name: string, link?: string) => void; assistant?: React.ReactElement; onAssistant?: () => void; notice?: boolean; dock?: BlobDock; onDock?: (dock: BlobDock) => void; className?: string }
export declare function BlobMenu(props: BlobMenuProps): React.ReactElement;
export interface AssistantAttachment { id: number; kind: 'file' | 'image' | 'text' | 'html' | 'pdf' | 'link' | 'scope'; name: string; url?: string; text?: string; size?: number }
export interface AssistantMessage { id: number; role: 'user' | 'assistant'; text: string; html?: string | null; atts: AssistantAttachment[]; error?: boolean }
export interface AssistantCardProps { onSend?: (text: string, attachments: AssistantAttachment[], messages: AssistantMessage[]) => string | { text: string; html?: string } | Promise<string | { text: string; html?: string }>; messages?: AssistantMessage[]; title?: string; status?: string; onClose?: () => void; className?: string; style?: React.CSSProperties }
export declare function AssistantCard(props: AssistantCardProps): React.ReactElement;
export interface ThinkingOrbProps { size?: number; thinking?: boolean; label?: string; className?: string }
export declare function ThinkingOrb(props: ThinkingOrbProps): React.ReactElement;
declare global { interface Window { ALFA: { Shell: typeof Shell; Lane: typeof Lane; LaneHandle: typeof LaneHandle; Blob: typeof Blob; TileMenu: typeof TileMenu; MessageRow: typeof MessageRow; SyncButton: typeof SyncButton; PersonMark: typeof PersonMark; TextButton: typeof TextButton; SymbolButton: typeof SymbolButton; Chip: typeof Chip; SearchField: typeof SearchField; Symbol: typeof Symbol; ArcBars: typeof ArcBars; PillStack: typeof PillStack; Tooltip: typeof Tooltip; DotSphere: typeof DotSphere; GlowButton: typeof GlowButton; AgentPill: typeof AgentPill; NumberRoll: typeof NumberRoll; SpotlightGrid: typeof SpotlightGrid; StackedCards: typeof StackedCards; KanbanBoard: typeof KanbanBoard; ReadingPane: typeof ReadingPane; HubTile: typeof HubTile; EditSheet: typeof EditSheet; BlobMenu: typeof BlobMenu; AssistantCard: typeof AssistantCard; ThinkingOrb: typeof ThinkingOrb } } }
