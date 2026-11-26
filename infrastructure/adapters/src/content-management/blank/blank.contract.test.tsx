import { describeContentManagementContract } from '../content-management.contract';

// The only implementation today. A CMS adapter should run the same suite with `publish`.
describeContentManagementContract('Blank', {
  load: () => import('./index'),
});
