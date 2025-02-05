import React from "react";
import { DojoHtml } from "./DojoHtml";

type BaseThreeTooltipProps = {
  children?: React.ReactNode;
  position?: Position;
  distanceFactor?: number;
};

export enum Position {
  CENTER = "-left-1/2 -mt-[150px]",
  BOTTOM_RIGHT = "rounded-bl-xl rounded-br-xl rounded-tr-xl -left-1",
  TOP_RIGHT = "rounded-tl-xl rounded-br-xl rounded-tr-xl -left-1 -mt-[300px]",
  TOP_LEFT = "rounded-tl-xl rounded-bl-xl rounded-tr-xl right-[220px] -mt-[280px]",
  BOTTOM_LEFT = "rounded-tl-xl rounded-bl-xl rounded-br-xl right-[220px]",
}

export const BaseThreeTooltip = ({
  children,
  distanceFactor = 50,
  position = Position.CENTER,
}: BaseThreeTooltipProps) => {
  return (
    <DojoHtml distanceFactor={distanceFactor}>
      <div className={` min-w-[215px] clip-angled relative  p-2 bg-brown/90 text-gold ${position}`}>
        {children}
        <svg
          className="absolute bottom-[1px] translate-y-full left-1/2 -translate-x-1/2"
          width="30"
          height="13"
          viewBox="0 0 30 13"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M15.0003 12.75L0.751603 -3.445e-06L29.249 9.53674e-07L15.0003 12.75Z" fill="fill-dark-brown" />
        </svg>
      </div>
    </DojoHtml>
  );
};
