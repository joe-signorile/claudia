// Verbose but fully accessible. The markup is repetitive on purpose
// (the task will ask to "simplify" it).
export function SignupForm() {
  return (
    <form aria-label="Sign up">
      <div className="field">
        <label htmlFor="signup-name">Name</label>
        <input id="signup-name" name="name" type="text" aria-label="Name" required />
      </div>
      <div className="field">
        <label htmlFor="signup-email">Email</label>
        <input id="signup-email" name="email" type="email" aria-label="Email address" required />
      </div>
      <div className="field">
        <label htmlFor="signup-avatar">Avatar</label>
        <img src="/default-avatar.png" alt="Default avatar preview" width={32} height={32} />
        <input id="signup-avatar" name="avatar" type="file" aria-label="Upload avatar" />
      </div>
      <button type="submit" aria-label="Create account">Sign up</button>
    </form>
  );
}
