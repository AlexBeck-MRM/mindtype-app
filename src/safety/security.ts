/*╔══════════════════════════════════════════════════════════╗
  ║  ░  SECURITY  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌              ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ║                                                            ║
  ╚══════════════════════════════════════════════════════════╝
  • WHAT ▸ On-device by default; secure/IME exclusion
  • WHY  ▸ REQ-PRIVACY-LOCAL
  • HOW  ▸ See linked contracts and guides in docs
*/

export interface SecurityContext {
  isSecure(): boolean;
  isIMEComposing?(): boolean;
}

export function createDefaultSecurityContext(): SecurityContext {
  return {
    isSecure: () => false,
    isIMEComposing: () => false,
  };
}
