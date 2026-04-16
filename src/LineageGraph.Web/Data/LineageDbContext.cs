using Microsoft.EntityFrameworkCore;
using LineageGraph.Web.Models;

namespace LineageGraph.Web.Data;

public class LineageDbContext : DbContext
{
    public LineageDbContext(DbContextOptions<LineageDbContext> options) : base(options)
    {
    }

    public DbSet<Node> Nodes => Set<Node>();
    public DbSet<Edge> Edges => Set<Edge>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Node configuration
        modelBuilder.Entity<Node>(entity =>
        {
            entity.ToTable("Nodes");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Transformation).HasMaxLength(255).IsRequired();
            entity.Property(e => e.IdType).HasColumnName("id_type");
            entity.Property(e => e.Proprietaire).HasMaxLength(100);
            entity.Property(e => e.DateCreation).HasColumnName("date_creation").HasDefaultValueSql("GETDATE()");
        });

        // Edge configuration
        modelBuilder.Entity<Edge>(entity =>
        {
            entity.ToTable("Edges");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.SourceNodeId).HasColumnName("source_node_id");
            entity.Property(e => e.TargetNodeId).HasColumnName("target_node_id");
            entity.Property(e => e.DataName).HasColumnName("data_name").HasMaxLength(100).IsRequired();

            entity.HasOne(e => e.SourceNode)
                .WithMany(n => n.OutgoingEdges)
                .HasForeignKey(e => e.SourceNodeId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.TargetNode)
                .WithMany(n => n.IncomingEdges)
                .HasForeignKey(e => e.TargetNodeId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
