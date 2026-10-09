// Stand-ins for what the sources import from their project: React and motion as page globals,
// the class name helper, a size hook, and small icons. Written for the starter cards only.

const { useState, useEffect, useRef, useMemo, useCallback, useId, useContext, createContext, useLayoutEffect, useReducer, Children, Fragment, forwardRef, memo, cloneElement, isValidElement } = React;
const createPortal = ReactDOM.createPortal;
const { motion, AnimatePresence, MotionConfig, LayoutGroup, useInView, useMotionValue, useMotionValueEvent, useMotionTemplate, useScroll, useSpring, useTransform, useVelocity, useAnimationFrame, useReducedMotion, useAnimate, animate, motionValue } = Motion;

// Joins class names and drops empty ones. Conflicting utilities are not merged.
function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

// Size of an element, kept up to date with a resize observer.
function useMeasure<T extends HTMLElement = HTMLDivElement>() {
  const ref = useRef<T>(null);
  const empty = { width: 0, height: 0, top: 0, left: 0, x: 0, y: 0, right: 0, bottom: 0 };
  const [bounds, setBounds] = useState(empty);
  useLayoutEffect(() => {
    const node = ref.current;
    if (!node || typeof ResizeObserver === 'undefined') return;
    const update = () => {
      const r = node.getBoundingClientRect();
      setBounds({ width: r.width, height: r.height, top: r.top, left: r.left, x: r.x, y: r.y, right: r.right, bottom: r.bottom });
    };
    update();
    const observer = new ResizeObserver(update);
    observer.observe(node);
    return () => observer.disconnect();
  }, []);
  return [ref, bounds] as const;
}

// Draws a stroke icon from simple paths on a 24 by 24 grid.
function makeIcon(paths: string[]) {
  return function Icon(props: any) {
    return (
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>
        {paths.map((d, i) => <path key={i} d={d} />)}
      </svg>
    );
  };
}

const X = makeIcon(['M18 6 6 18', 'm6 6 12 12']);
const XIcon = X;
const PlusIcon = makeIcon(['M12 5v14', 'M5 12h14']);
const ArrowLeft = makeIcon(['m12 19-7-7 7-7', 'M19 12H5']);
const ArrowRight = makeIcon(['M5 12h14', 'm12 5 7 7-7 7']);
const ChevronLeft = makeIcon(['m15 18-6-6 6-6']);
const ChevronRight = makeIcon(['m9 18 6-6-6-6']);
const Search = makeIcon(['M11 4a7 7 0 1 0 0 14 7 7 0 1 0 0-14', 'm21 21-4.3-4.3']);
const User = makeIcon(['M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2', 'M12 3a4 4 0 1 0 0 8 4 4 0 1 0 0-8']);
const Folder = makeIcon(['M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z']);
const MessageCircle = makeIcon(['M21 12a8 8 0 0 1-11.5 7.2L4 20l1-4.5A8 8 0 1 1 21 12z']);
const Activity = makeIcon(['M3 12h4l3-8 4 16 3-8h4']);
const Component = makeIcon(['M4 4h6v6H4z', 'M14 4h6v6h-6z', 'M4 14h6v6H4z', 'M14 14h6v6h-6z']);
const HomeIcon = makeIcon(['M3 11 12 4l9 7', 'M5 10v10h14V10']);
const WalletCards = makeIcon(['M3 8h18v10H3z', 'M3 11h18', 'M7 15h3']);
const Mail = makeIcon(['M4 5h16v14H4z', 'm4 7 8 6 8-6']);
const Package = makeIcon(['M12 3 4 7v10l8 4 8-4V7z', 'M4 7l8 4 8-4', 'M12 11v10']);
const ScrollText = makeIcon(['M8 21h10a2 2 0 0 0 2-2V5H8z', 'M8 9H4v8a2 2 0 0 0 2 2', 'M11 8h4', 'M11 12h4']);
const SunMoon = makeIcon(['M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z']);
