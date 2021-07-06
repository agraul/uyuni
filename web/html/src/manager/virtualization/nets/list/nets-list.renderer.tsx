import * as React from "react";
import { NetsList } from "./nets-list";
import SpaRenderer from "core/spa/spa-renderer";

type RendererProps = {
  serverId: string;
  pageSize: number;
  hypervisor: string;
  support_enhanced_network: boolean;
};

export const renderer = (id: string, { serverId, pageSize, hypervisor, support_enhanced_network }: RendererProps) => {
  SpaRenderer.renderNavigationReact(
    <NetsList
      serverId={serverId}
      pageSize={pageSize}
      hypervisor={hypervisor}
      allow_changing={support_enhanced_network}
    />,
    document.getElementById(id)
  );
};
