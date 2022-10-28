using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace drumbeat.Data;

public class ApplicationDbContext : IdentityDbContext
{

    public DbSet<ImageScore> ImageScores { get; set; }
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }
}
