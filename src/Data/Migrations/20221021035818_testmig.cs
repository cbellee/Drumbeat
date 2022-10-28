using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace drumbeat.Data.Migrations
{
    public partial class testmig : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ImageScores_AspNetUsers_UserId",
                table: "ImageScores");

            migrationBuilder.RenameColumn(
                name: "UserId",
                table: "ImageScores",
                newName: "ApplicationUserId");

            migrationBuilder.RenameIndex(
                name: "IX_ImageScores_UserId",
                table: "ImageScores",
                newName: "IX_ImageScores_ApplicationUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_ImageScores_AspNetUsers_ApplicationUserId",
                table: "ImageScores",
                column: "ApplicationUserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ImageScores_AspNetUsers_ApplicationUserId",
                table: "ImageScores");

            migrationBuilder.RenameColumn(
                name: "ApplicationUserId",
                table: "ImageScores",
                newName: "UserId");

            migrationBuilder.RenameIndex(
                name: "IX_ImageScores_ApplicationUserId",
                table: "ImageScores",
                newName: "IX_ImageScores_UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_ImageScores_AspNetUsers_UserId",
                table: "ImageScores",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id");
        }
    }
}
