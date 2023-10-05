import * as React from "react";

import SpaRenderer from "core/spa/spa-renderer";

import { GuestsList } from "./guests-list";
import { HostInfo } from "./guests-list";

type RendererProps = {
  serverId: string;
  saltEntitled: boolean;
  foreignEntitled: boolean;
  isAdmin: boolean;
  hostInfo?: HostInfo;
};

export const renderer = (id: string, { serverId, saltEntitled, foreignEntitled, isAdmin, hostInfo }: RendererProps) => {
  SpaRenderer.renderNavigationReact(
    <GuestsList
      serverId={serverId}
      saltEntitled={saltEntitled}
      foreignEntitled={foreignEntitled}
      isAdmin={isAdmin}
      hostInfo={hostInfo}
    />,
    document.getElementById(id)
  );
};
