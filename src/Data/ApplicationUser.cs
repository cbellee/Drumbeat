using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace drumbeat.Data;

public class ApplicationUser : IdentityUser
{
    public virtual ICollection<ImageScore>? ImageScores { get; set; }
}

